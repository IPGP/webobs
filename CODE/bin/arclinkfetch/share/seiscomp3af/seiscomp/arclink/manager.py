#***************************************************************************** 
# manager.py
#
# ArcLink higher-level client support
#
# (c) 2005 Andres Heinloo, GFZ Potsdam
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version. For more information, see http://www.gnu.org/
#*****************************************************************************

import socket
import cStringIO
import threading
import fnmatch
from tempfile import NamedTemporaryFile
from seiscomp import logs
from seiscomp.db.generic.routing import Routing as _Routing
from seiscomp.db.generic.inventory import Inventory as _Inventory
from seiscomp.arclink.client import *

_DEFAULT_USER = "guest@anywhere"
_SOCKET_TIMEOUT = 300
_REQUEST_TIMEOUT = 300  # currently not used
_DOWNLOAD_RETRY = 5

class _Request(object):
    def __init__(self, rtype, args, label, socket_timeout, request_timeout,
        download_retry):
        self.rtype = rtype
        self.args = args
        self.label = label
        self.socket_timeout = socket_timeout
        self.request_timeout = request_timeout
        self.download_retry = download_retry
        self.content = []
        self.address = None
        self.dcname = None
        self.error = None
        self.id = None
        self.__arcl = Arclink()
        self.__arcl_wait = None
        self.__host = None
        self.__port = None
        self.__user = None
        self.__passwd = None
        self.__status = None
#BIANCHI|ENCRYPTION: Password for decrypting data.
        self.encStatus = None
        self.decStatus = None

    def new(self):
        return _Request(self.rtype, self.args, self.label, self.socket_timeout,
            self.request_timeout, self.download_retry)
    
    def add(self, network, station, stream, loc_id, begin, end,
        constraints = None, server_blacklist = None):
        
        if constraints is None:
            constraints = {}

        if server_blacklist is None:
            server_blacklist = set()

        self.content.append((network, station, stream, loc_id, begin, end,
            constraints, server_blacklist))
    
    def dump(self, fd):
        if self.label:
             print >>fd, "LABEL %s" % (self.label,)

        print >>fd, "REQUEST %s %s" % (self.rtype,
            " ".join([ "%s=%s" % (a, v) for a, v in self.args.iteritems() ]))

        for (network, station, stream, loc_id, begin, end, constraints, blacklist) in self.content:
            print >>fd, "%d,%d,%d,%d,%d,%d %d,%d,%d,%d,%d,%d %s %s %s %s %s" % \
                (begin.year, begin.month, begin.day, begin.hour, begin.minute, begin.second,
                end.year, end.month, end.day, end.hour, end.minute, end.second,
                network, station, stream, loc_id,
                " ".join([ "%s=%s" % (a, v) for a, v in constraints.iteritems() ]))

        print >>fd, "END"

    def submit(self, addr, user, passwd=None, user_ip=None):
        try:
            (host, port) = addr.split(':')
            port = int(port)
        except ValueError:
            self.error = "invalid ArcLink address"
            return

        try:
            self.__arcl.open_connection(host, port, user, passwd, None,
                self.socket_timeout, user_ip)

            try:
                reqf = cStringIO.StringIO()
                try:
                    self.dump(reqf)
                    reqf.seek(0)
                    self.id = self.__arcl.submit(reqf)
                    self.__host = host
                    self.__port = port
                    self.__user = user
                    self.__passwd = passwd
                    self.address = addr
                    self.dcname = self.__arcl.organization

                finally:
                    reqf.close()

            finally:
                self.__arcl.close_connection()
                
        except (ArclinkError, socket.error), e:
            self.error = str(e)

    def status(self):
        if self.id is None:
            raise ArclinkError, "request not submitted"
        
        if self.__status:
            return self.__status

        self.__arcl.open_connection(self.__host, self.__port, self.__user,
            self.__passwd, None, self.socket_timeout)

        try:
            # This method should return the FULL status including the ARCLINK node.
            # This would avoid the creation of the 'dcencryption' variable
            status = self.__arcl.get_status(self.id).request[0]
            if status.ready:
                self.__status = status
                
            return status

        finally:
            self.__arcl.close_connection()

    def wait(self):
        if self.id is None:
            raise ArclinkError, "request not submitted"
        
        self.__arcl_wait = Arclink()

        retry = 0

        while True:
            self.__arcl_wait.open_connection(self.__host, self.__port,
                self.__user, self.__passwd, None, self.socket_timeout)

            try:
                self.__arcl_wait.wait(self.id, timeout=self.socket_timeout)
                break

            except ArclinkTimeout, e:
                reason = str(e)

                retry += 1
                if retry > self.download_retry:
                    self.__arcl_wait.close_connection()
                    self.__arcl_wait = None
                    raise ArclinkError, "download failed: " + reason

    def close(self):
        if self.__arcl_wait:
            self.__arcl_wait.close_connection()
            self.__arcl_wait = None
    
    def download_data(self, fd, vol_id=None, block=False, purge=True, password=None, raw=False):
        if self.id is None:
            raise ArclinkError, "request not submitted"
        
        retry = 0
        if block:
            tmo = self.socket_timeout
        else:
            tmo = 0
        
        if vol_id is not None:
            self.close()
        
        while True:
            if self.__arcl_wait:
                arcl = self.__arcl_wait
                self.__arcl_wait = None
            else:
                arcl = self.__arcl
                arcl.open_connection(self.__host, self.__port,
                    self.__user, self.__passwd, None, self.socket_timeout)

            try:
                try:
#BIANCHI|ENCRYPTION: Check what we will get.
                    (self.encStatus, self.decStatus) = arcl.download_data(fd, self.id, vol_id, timeout=tmo, password=password, raw=raw)

                    if purge:
                        arcl.purge(self.id)
                        self.id = None

                    break

                except ArclinkTimeout, e:
                    reason = str(e)

                    try:
                        if arcl.errstate():
                            fd.seek(0)
                            fd.truncate(0)

                    except IOError:
                        raise ArclinkError, "download failed: " + reason
 
                    retry += 1
                    if retry > self.download_retry:
                        raise ArclinkError, "download failed: " + reason

            finally:
                arcl.close_connection()

    def download_xml(self, db, block=False, purge=True):
        if self.id is None:
            raise ArclinkError, "request not submitted"
        
        retry = 0
        if block:
            tmo = self.socket_timeout
        else:
            tmo = 0
        
        while True:
            arcl = self.__arcl
            self.__arcl_wait = None
            arcl.open_connection(self.__host, self.__port,
                self.__user, self.__passwd, None, self.socket_timeout)
                
            try:
                try:
                    arcl.download_xml(db, self.id, timeout=tmo)

                    if purge:
                        arcl.purge(self.id)
                        self.id = None

                    break

                except ArclinkTimeout, e:
                    retry += 1
                    if retry > self.download_retry:
                        raise ArclinkError, "download failed: " + str(e)
                    
            finally:
                arcl.close_connection()

    def purge(self):
        if self.id is None:
            return

        self.__arcl.open_connection(self.__host, self.__port, self.__user,
            self.__passwd, None, self.socket_timeout)

        try:
            self.__arcl.purge(self.id)

        finally:
            self.__arcl.close_connection()
    
class RequestThread(threading.Thread):
    def __init__(self, req, addr, user, passwd, user_ip, req_sent, req_retry):
        threading.Thread.__init__(self)
        self.__req = req
        self.__addr = addr
        self.__user = user
        self.__passwd = passwd
        self.__user_ip = user_ip
        self.__req_sent = req_sent
        self.__req_retry = req_retry

    def run(self):
        try:
            self.__req.submit(self.__addr, self.__user, self.__passwd, self.__user_ip)
            if self.__req.error is not None:
                logs.warning("error submitting request to %s: %s" %
                    (self.__addr, self.__req.error))

                for item in self.__req.content:
                    item[7].add(self.__addr) #blacklist
                    self.__req_retry.add(*item)

                return

            self.__req.wait()
            logs.debug("%s: request %s ready" % (self.__req.address, self.__req.id))

            fail_content = {}
            for (net, sta, strm, loc, begin, end, constraints, blacklist) in self.__req.content:
                key = ("%d,%d,%d,%d,%d,%d %d,%d,%d,%d,%d,%d %s %s %s %s %s" %
                    (begin.year, begin.month, begin.day, begin.hour, begin.minute, begin.second,
                    end.year, end.month, end.day, end.hour, end.minute, end.second, net, sta, strm, loc,
                    " ".join([ "%s=%s" % (a, v) for a, v in constraints.iteritems() ]))).strip()

                blacklist.add(self.__addr)
                fail_content[key] = (net, sta, strm, loc, begin, end, constraints, blacklist)

            rqstat = self.__req.status()
            for vol in rqstat.volume:
                for rqln in vol.line:
                    if (vol.status != STATUS_OK and vol.status != STATUS_WARN and vol.status != STATUS_DENIED) or \
                        (rqln.status != STATUS_OK and rqln.status != STATUS_WARN and rqln.status != STATUS_DENIED):
                        self.__req_retry.content.append(fail_content[rqln.content.strip()])

            #self.__req.purge()
            self.__req_sent.append(self.__req)
            return

        except ArclinkError, e:
            try:
                rqstat = self.__req.status()
                if rqstat.error:
                    logs.warning("%s: request %s failed (%s)" % (self.__req.address, self.__req.id, str(e)))
                
                else:
                    logs.warning("%s: request %s returned no data (%s)" % (self.__req.address, self.__req.id, str(e)))

                #self.__req.purge()
                self.__req_sent.append(self.__req)

            except (ArclinkError, socket.error), e:
                logs.warning("%s: error: %s" % (self.__req.address, str(e)))
                        
        except socket.error, e:
            logs.warning("%s: error: %s" % (self.__req.address, str(e)))

        for item in self.__req.content:
            item[7].add(self.__addr) #blacklist
            self.__req_retry.add(*item)

class ArclinkManager(object):
    def __init__(self, address, default_user = _DEFAULT_USER, user_ip = None,
        pwtable = {}, addr_alias = {}, socket_timeout = _SOCKET_TIMEOUT,
        request_timeout = _REQUEST_TIMEOUT, download_retry = _DOWNLOAD_RETRY):
        self.__myaddr = address
        self.__default_user = default_user
        self.__user_ip = user_ip
        self.__pwtable = pwtable
        self.__addr_alias = addr_alias
        self.__socket_timeout = socket_timeout
        self.__request_timeout = request_timeout
        self.__download_retry = download_retry

        usr_pwd = self.__pwtable.get(address)
        if usr_pwd is None:
            self.__myuser = self.__default_user
            self.__mypasswd = None
        else:
            (self.__myuser, self.__mypasswd) = usr_pwd

        alias = self.__addr_alias.get(address)
        if alias is None:
            self.__myaddr = address
        else:
            self.__myaddr = alias

    def checkServer(self):
        try:
            (host, port) = self.__myaddr.split(':')
            port = int(port)
        except ValueError:
            raise Exception("Hostname should be in a form of host:port")
        
        try:
            socket.gethostbyname(host)
        except socket.error:
            raise Exception("Cannot resolv supplied address")
            
        # Test that the ArcLink server is up and running
        try:
            acl = self.__arcl = Arclink()
            acl.open_connection(host, port, self.__myuser)
            acl.close_connection()
	    acl = None
        except Exception, e:
            raise Exception("Arclink Server is down.")
        
    def new_request(self, rtype, args={}, label=None):
        return _Request(rtype, args, label, self.__socket_timeout,
            self.__request_timeout, self.__download_retry)
 
    def get_inventory(self, network = "*", station = ".", stream = ".",
        loc_id = ".", begin = None, end = None, sensortype = None,
        permanent = None, restricted = None, latmin = None, latmax = None,
        lonmin = None, lonmax = None, instr = False, allnet = False,
        modified_after = None, qc_constraints = None):

        constraints = {}

        if qc_constraints is not None:
            constraints = qc_constraints

        if sensortype is not None:
            constraints['sensortype'] = sensortype

        if permanent is not None:
            if permanent:
                constraints['permanent'] = 'true'
            else:
                constraints['permanent'] = 'false'

        if restricted is not None:
            if restricted:
                constraints['restricted'] = 'true'
            else:
                constraints['restricted'] = 'false'
        
        if latmin is not None:
            constraints['latmin'] = str(latmin)

        if latmax is not None:
            constraints['latmax'] = str(latmax)

        if lonmin is not None:
            constraints['lonmin'] = str(lonmin)

        if lonmax is not None:
            constraints['lonmax'] = str(lonmax)

        if begin is None:
            begin = datetime.datetime(1980,1,1,0,0,0)

        if end is None:
            end = datetime.datetime(2030,12,31,0,0,0)

        args = { 'compression': 'bzip2' }
        if instr:
            args['instruments'] = 'true'
        else:
            args['instruments'] = 'false'
        
        if modified_after is not None:
            args['modified_after'] = modified_after.isoformat()
        
        req = self.new_request("INVENTORY", args)
        req.add(network, station, stream, loc_id, begin, end, constraints)

        if allnet:
            req.add("*", ".", ".", ".", begin, end, constraints)

        req.submit(self.__myaddr, self.__myuser, self.__mypasswd, self.__user_ip)

        if req.error is not None:
            raise ArclinkError, req.error
        
        db = _Inventory()
        req.download_xml(db, True)
        return db

    def __expand_request(self, req, inv):
        def _dot(s):
            if not s:
                return "."

            return s

        for i in req.content:
            if i[0] in inv.stationGroup:
                break

            for j in i[:4]:
                if j.find("*") >= 0 or j.find("?") >= 0:
                    break
            else:
                continue

            break

        else:
            return

        content = []

        for (net_code, sta_code, strm_code, loc_code, begin, end, constraints, blacklist) in req.content:
            expanded = set()

            for sgrp in inv.stationGroup.itervalues():
                if not fnmatch.fnmatchcase(sgrp.code, net_code):
                    continue

                for sref in sgrp.stationReference.itervalues():
                    for net in sum([i.values() for i in inv.network.itervalues()], []):
                        try:
                            sta = net.object[sref.stationID]
                            break

                        except KeyError:
                            pass

                    else:
                        continue

                    for loc in sum([i.values() for i in sta.sensorLocation.itervalues()], []):
                        if not fnmatch.fnmatchcase(_dot(loc.code), _dot(loc_code)):
                            continue
                        
                        for strm in sum([i.values() for i in loc.stream.itervalues()], []):
                            if fnmatch.fnmatchcase(strm.code, strm_code):
                                expanded.add((net.code, sta.code, strm.code, _dot(loc.code), begin, end))
                        
                        for strm in sum([i.values() for i in loc.auxStream.itervalues()], []):
                            if fnmatch.fnmatchcase(strm.code, strm_code):
                                expanded.add((net.code, sta.code, strm.code, _dot(loc.code), begin, end))

            for net in sum([i.values() for i in inv.network.itervalues()], []):
                if not fnmatch.fnmatchcase(net.code, net_code):
                    continue

                for sta in sum([i.values() for i in net.station.itervalues()], []):
                    if not fnmatch.fnmatchcase(sta.code, sta_code):
                        continue

                    for loc in sum([i.values() for i in sta.sensorLocation.itervalues()], []):
                        if not fnmatch.fnmatchcase(_dot(loc.code), _dot(loc_code)):
                            continue
                        
                        for strm in sum([i.values() for i in loc.stream.itervalues()], []):
                            if fnmatch.fnmatchcase(strm.code, strm_code):
                                expanded.add((net.code, sta.code, strm.code, _dot(loc.code), begin, end))
                        
                        for strm in sum([i.values() for i in loc.auxStream.itervalues()], []):
                            if fnmatch.fnmatchcase(strm.code, strm_code):
                                expanded.add((net.code, sta.code, strm.code, _dot(loc.code), begin, end))

            if expanded:
                for x in expanded:
                    content.append(x + (constraints, blacklist))
            
            else:
                logs.warning("no match for %d,%d,%d,%d,%d,%d %d,%d,%d,%d,%d,%d %s %s %s %s %s" % \
                    (begin.year, begin.month, begin.day, begin.hour, begin.minute, begin.second,
                    end.year, end.month, end.day, end.hour, end.minute, end.second,
                    net_code, sta_code, strm_code, loc_code,
                    " ".join([ "%s=%s" % (a, v) for a, v in constraints.iteritems() ])))

        req.content[:] = content

    def __execute(self, db, request, req_sent, req_noroute, req_nodata):
        def _cmptime(t1, t2):
            if t1 is None and t2 is None:
                return 0
            elif t2 is None or (t1 is not None and t1 < t2):
                return -1
            elif t1 is None or (t2 is not None and t1 > t2):
                return 1

            return 0

        req_retry = request.new()
        req_route = {}
        
        for item in request.content:
            for x in (15, 14, 13, 11, 7, 12, 10, 9, 6, 5, 3, 8, 4, 2, 1, 0):
                net = (item[0], "")[not (x & 8)]
                sta = (item[1], "")[not (x & 4)]
                cha = (item[2], "")[not (x & 2)]
                loc = (item[3], "")[not (x & 1)]

                try:
                    route = db.route[net][sta][loc][cha]
                    break

                except KeyError:
                    continue

            else:
                logs.warning("route to station %s %s not found" % (item[0], item[1]))
                req_noroute.add(*item)
                continue

            server_list = sum([i.values() for i in route.arclink.itervalues()], [])
            server_list.sort(key=lambda x: x.priority)
            arclink_addrs = []
            for server in server_list:
                if _cmptime(server.start, item[5]) > 0 or \
                    _cmptime(server.end, item[4]) < 0:
                    continue

                alias = self.__addr_alias.get(server.address)
                if alias is None:
                    arclink_addrs.append(server.address)
                else:
                    arclink_addrs.append(alias)
            
            for addr in arclink_addrs:
                if addr not in item[7]: #blacklist
                    if addr not in req_route:
                        req_route[addr] = request.new()

                    req_route[addr].add(*item)
                    break
            else:
                if arclink_addrs:
                    req_nodata.add(*item)
                else:
                    req_noroute.add(*item)

        req_thr = []
        for (addr, req) in req_route.items():
            usr_pwd = self.__pwtable.get(addr)
            if usr_pwd is None:
                user = self.__default_user
                passwd = None
            else:
                (user, passwd) = usr_pwd
                    
            logs.info("launching request thread (%s)" % (addr,))
            thr = RequestThread(req, addr, user, passwd, self.__user_ip, req_sent, req_retry)
            thr.start()
            req_thr.append(thr)

        for thr in req_thr:
            thr.join()

        if req_retry.content:
            return self.__execute(db, req_retry, req_sent, req_noroute, req_nodata)
        
    def execute(self, request, use_inventory = True, use_routing = True):
        if len(request.content) == 0:
            raise ArclinkError, "empty request"

        inv = _Inventory()
        rtn = _Routing()

        req_sent = []
        req_noroute = request.new()
        req_nodata = request.new()

        if use_inventory:
            logs.debug("requesting inventory from %s" % (self.__myaddr))
            args = {'instruments': 'true', 'compression': 'bzip2'}
            req = self.new_request("INVENTORY", args, request.label)
            req.content = request.content
            req.submit(self.__myaddr, self.__myuser, self.__mypasswd, self.__user_ip)

            if req.error is not None:
                raise ArclinkError, "error getting inventory data from %s: %s" % \
                    (self.__myaddr, req.error)
            
            req.download_xml(inv, True)

            if use_routing:
                self.__expand_request(request, inv)
                if len(request.content) == 0:
                    raise ArclinkError, "empty request after wildcard expansion"

        if use_routing:
            logs.debug("requesting routing from %s" % (self.__myaddr))
            args = { 'compression': 'bzip2' }
            req = self.new_request("ROUTING", args, request.label)
            req.content = request.content
            req.submit(self.__myaddr, self.__myuser, self.__mypasswd, self.__user_ip)

            if req.error is not None:
                raise ArclinkError, "error getting routing data from %s: %s" % \
                    (self.__myaddr, req.error)
            
            req.download_xml(rtn, True)
            self.__execute(rtn, request, req_sent, req_noroute, req_nodata)

        else:
            logs.debug("requesting waveform data from %s" % (self.__myaddr))
            request.submit(self.__myaddr, self.__myuser, self.__mypasswd, self.__user_ip)

            if request.error is not None:
                raise ArclinkError, "error getting waveform data from %s: %s" % \
                    (self.__myaddr, request.error)
            
            request.wait()
            req_sent.append(request)

        if not req_noroute.content:
            req_noroute = None

        if not req_nodata.content:
            req_nodata = None

        return (inv, req_sent, req_noroute, req_nodata)

    ############################# Obsolete methods #############################

    def __route_request(self, db, blacklist, req_ok, request):
        def _cmptime(t1, t2):
            if t1 is None and t2 is None:
                return 0
            elif t2 is None or (t1 is not None and t1 < t2):
                return -1
            elif t1 is None or (t2 is not None and t1 > t2):
                return 1

            return 0

        req_fail = None
        req_route = {}
        
        for item in request.content:
            for x in (15, 14, 13, 11, 7, 12, 10, 9, 6, 5, 3, 8, 4, 2, 1, 0):
                net = (item[0], "")[not (x & 8)]
                sta = (item[1], "")[not (x & 4)]
                cha = (item[2], "")[not (x & 2)]
                loc = (item[3], "")[not (x & 1)]

                try:
                    route = db.route[net][sta][loc][cha]
                    break

                except KeyError:
                    continue

            else:
                logs.warning("route to station %s %s not found" % (item[0], item[1]))
                if req_fail is None:
                    req_fail = request.new()
                    
                req_fail.add(*item)
                continue

            server_list = sum([i.values() for i in route.arclink.itervalues()], [])
            server_list.sort()
            arclink_addrs = []
            for server in server_list:
                if _cmptime(server.start, item[5]) > 0 or \
                    _cmptime(server.end, item[4]) < 0:
                    continue

                alias = self.__addr_alias.get(server.address)
                if alias is None:
                    arclink_addrs.append(server.address)
                else:
                    arclink_addrs.append(alias)
            
            if self.__myaddr in arclink_addrs:
                if self.__myaddr not in req_route:
                    req_route[self.__myaddr] = request.new()
                    
                req_route[self.__myaddr].add(*item)
            else:
                for (addr, req) in req_route.iteritems():
                    if addr in arclink_addrs:
                        req.add(*item)
                        break
                else:
                    for addr in arclink_addrs:
                        if addr not in blacklist:
                            req_route[addr] = request.new()
                            req_route[addr].add(*item)
                            break
                    else:
                        if req_fail is None:
                            req_fail = request.new()
                            
                        req_fail.add(*item)

        for (addr, req) in req_route.items():
            usr_pwd = self.__pwtable.get(addr)
            if usr_pwd is None:
                user = self.__default_user
                passwd = None
            else:
                (user, passwd) = usr_pwd
                    
            req.submit(addr, user, passwd, self.__user_ip)
            if req.error is not None:
                logs.warning("error submitting request to %s: %s" %
                    (addr, req.error))

                if addr == self.__myaddr:
                    logs.warning("blacklisting primary ArcLink server")
                
                if req_fail is None:
                    req_fail = request.new()

                for item in req.content:
                    req_fail.add(*item)

                del req_route[addr]
                blacklist.add(addr)
 
        req_ok += req_route.values()
        
        if req_fail is not None and len(req_route) > 0:
            return self.__route_request(db, blacklist, req_ok, req_fail)
        
        return req_fail

    def route_request(self, request, blacklist = None):
        if len(request.content) == 0:
            return ([], None)
        
        args = {'instruments': 'false', 'compression': 'bzip2'}
        req = self.new_request("INVENTORY", args, request.label)
        req.content = request.content
        req.submit(self.__myaddr, self.__myuser, self.__mypasswd, self.__user_ip)

        if req.error is not None:
            raise ArclinkError, req.error

        db = _Inventory()
        req.download_xml(db, True)

        self.__expand_request(request, db)
        if len(request.content) == 0:
            raise ArclinkError, "empty request after wildcard expansion"

        args = { 'compression': 'bzip2' }
        req = self.new_request("ROUTING", args, request.label)
        req.content = request.content
        req.submit(self.__myaddr, self.__myuser, self.__mypasswd, self.__user_ip)

        if req.error is not None:
            raise ArclinkError, req.error
        
        db = _Routing()
        req.download_xml(db, True)

        if blacklist is None:
            blacklist = set()

        req_ok = []
        req_fail = self.__route_request(db, blacklist, req_ok, request)

        return (req_ok, req_fail)

