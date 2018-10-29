#*****************************************************************************
# arclink_fetch.py
#
# ArcLink command-line client with routing support
#
# (c) 2009 Andres Heinloo, GFZ Potsdam
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version. For more information, see http://www.gnu.org/
#*****************************************************************************

import os
import sys
import datetime
import shutil
from optparse import OptionParser
from tempfile import TemporaryFile
from breqfast import BreqParser
from seiscomp import logs
from seiscomp.arclink.manager import *
from seiscomp.db import DBError
from seiscomp.db.generic.inventory import Inventory
from seiscomp.mseedlite import Input as MSeedInput, MSeedError
from seiscomp.fseed import SEEDVolume, SEEDError, _WaveformData

VERSION = "1.2.1 (2011.269)"

ORGANIZATION = "WebDC"
LABEL = "WebDC SEED Volume"

verbosity = 1

class SeedOutput(object):
    def __init__(self, fd, inv, resp_dict):
        self.__fd = fd
        self.__inv = inv
        self.__resp_dict = resp_dict
        self.__mseed_fd = TemporaryFile()

    def write(self, data):
        self.__mseed_fd.write(data)

    def close(self):
        try:
            try:
                seed_volume = SEEDVolume(self.__inv, ORGANIZATION, LABEL,
                    self.__resp_dict)

                self.__mseed_fd.seek(0)
                for rec in MSeedInput(self.__mseed_fd):
                    seed_volume.add_data(rec)

                seed_volume.output(self.__fd)

            except (MSeedError, SEEDError, DBError), e:
                logs.error("error creating SEED volume: " + str(e))

        finally:
            self.__mseed_fd.close()
            self.__fd.close()

class MSeed4KOutput(object):
    def __init__(self, fd):
        self.__fd = fd
        self.__mseed_fd = TemporaryFile()

    def write(self, data):
        self.__mseed_fd.write(data)

    def close(self):
        try:
            try:
                wfd = _WaveformData()

                self.__mseed_fd.seek(0)
                for rec in MSeedInput(self.__mseed_fd):
                    wfd.add_data(rec)

                wfd.output_data(self.__fd, 0)

            except (MSeedError, SEEDError, DBError), e:
                logs.error("error reblocking Mini-SEED data: " + str(e))

        finally:
            self.__mseed_fd.close()
            self.__fd.close()

def show_status(request):
    try:
        logs.info("datacenter name: " + request.dcname)
        rqstat = request.status()
    except ArclinkError, e:
        logs.error(str(e))
        return
    
    if rqstat.error:
        req_status = "ERROR"
    elif rqstat.ready:
        req_status = "READY"
    else:
        req_status = "PROCESSING"
    
    IrequestCompressed = request.args.get("compression")
    
    logs.info("request ID: %s, Label: %s, Type: %s, Encrypted: %s, Args: %s" % \
        (rqstat.id, rqstat.label, rqstat.type, rqstat.encrypted, rqstat.args))
    logs.info("status: %s, Size: %d, Info: %s" % \
        (req_status, rqstat.size, rqstat.message))
    
    for vol in rqstat.volume:
        logs.info("    volume ID: %s, dcid: %s, Status: %s, Size: %d, Encrypted: %s, Info: %s" % \
            (vol.id, vol.dcid, arclink_status_string(vol.status), vol.size, vol.encrypted, vol.message))
    
        for rqln in vol.line:
            logs.info("        request: %s" % (rqln.content,))
            logs.info("        status: %s, Size: %d, Info: %s" % \
              (arclink_status_string(rqln.status), rqln.size, rqln.message))

    logs.info("")

def parse_native(req, input_file):
    fd = open(input_file)
    try:
        rqline = fd.readline()
        while rqline:
            rqline = rqline.strip()
            if not rqline:
                rqline = fd.readline()
                logs.debug("skipping empty request line")
                continue
                
            rqsplit = rqline.split()
            if len(rqsplit) < 3:
                logs.error("invalid request line: '%s'" % (rqline,))
                rqline = fd.readline()
                continue

            try:
                start_time = datetime.datetime(*map(int, rqsplit[0].split(",")))
                end_time = datetime.datetime(*map(int, rqsplit[1].split(",")))
            except ValueError, e:
                logs.error("syntax error (%s): '%s'" % (str(e), rqline))
                rqline = fd.readline()
                continue

            network = rqsplit[2]
            station = "."
            channel = "."
            location = "."

            i = 3
            if len(rqsplit) > 3 and rqsplit[3] != ".":
                station = rqsplit[3]
                i += 1
                if len(rqsplit) > 4 and rqsplit[4] != ".":
                    channel = rqsplit[4]
                    i += 1
                    if len(rqsplit) > 5 and rqsplit[5] != ".":
                        location = rqsplit[5]
                        i += 1
                        
            while len(rqsplit) > i and rqsplit[i] == ".":
                i += 1
            
            constraints = {}
            for arg in rqsplit[i:]:
                pv = arg.split('=', 1)
                if len(pv) != 2:
                    raise ArclinkHandlerError, "invalid request syntax"
                
                constraints[pv[0]] = pv[1]

            req.add(network, station, channel, location, start_time, end_time,
                constraints)
            
            rqline = fd.readline()

    finally:
        fd.close()

def parse_breqfast(req, input_file):
    parser = BreqParser()
    parser.parse_email(input_file)
    req.content = parser.reqlist
    logs.debug("")
    if parser.failstr:
        logs.error(parser.failstr)
    else:
        logs.info("parsed %d lines from breqfast message" % len(req.content))

def add_verbosity(option, opt_str, value, parser):
    global verbosity
    verbosity += 1

def add_quietness(option, opt_str, value, parser):
    global verbosity
    verbosity -= 1

def process_options():
    parser = OptionParser(usage="usage: %prog [-h|--help] [OPTIONS] -u USER -o OUTPUTFILE REQUEST", version="%prog v" + VERSION, add_help_option=False)

    parser.set_defaults(address = "webdc.eu:18001",
                        request_format = "native",
                        data_format = "mseed",
                        no_resp_dict = False,
                        rebuild_volume = False,
                        proxymode = False,
                        timeout = 300,
                        retries = 5,
                        SSLpasswordFile = "dcidpasswords.txt")

    parser.add_option("-h", "--help", action="store_true", dest="showhelp", default=False)
    parser.add_option("-l", "--longhelp", action="store_true", dest="showlonghelp", default=False)

    parser.add_option("-w","--password-file", type="string", dest="SSLpasswordFile",
      help="file containing passwords used for decryption of encrypted data (default %default)")

    parser.add_option("-a", "--address", type="string", dest="address",
      help="address of primary ArcLink node (default %default)")

    foptions = ("native", "breqfast")
    parser.add_option("-f", "--request-format", type="choice", dest="request_format", choices=foptions,
      help="request format: breqfast, native (default %default)")

    koptions = ("mseed", "mseed4k", "fseed", "dseed", "inv", "inventory")
    parser.add_option("-k", "--data-format", type="choice", dest="data_format", choices=koptions,
      help="data format: mseed, mseed4k, fseed, dseed, inv[entory] (default %default)")

    parser.add_option("-n", "--no-resp-dict", action="store_true", dest="no_resp_dict",
      help="avoid using response dictionary (default %default)")

    parser.add_option("-g", "--rebuild-volume", action="store_true", dest="rebuild_volume",
      help="rebuild SEED volume (default %default)")

    parser.add_option("-p", "--proxy", action="store_true", dest="proxymode",
      help="proxy mode, no routing (default %default)")

    parser.add_option("-t", "--timeout", type="int", dest="timeout",
      help="timeout in seconds (default %default)")

    parser.add_option("-x", "--retries", type="int", dest="retries",
      help="download retries (default %default)")

    parser.add_option("-v", action="callback", callback=add_verbosity,
      help="increase verbosity level")
    
    parser.add_option("-q", action="callback", callback=add_quietness,
      help="decrease verbosity level")
    
    parser.add_option("-u", "--user", type="string", dest="user",
      help="user's e-mail address")

    parser.add_option("-o", "--output-file", type="string", dest="output_file",
      help="file where downloaded data is written")

    (options, args) = parser.parse_args()

    if options.showhelp or options.showlonghelp:
        parser.print_help();
        if options.showlonghelp:
            print """
About ArcLink Protocol
====================== 

The ArcLink  is a protocol  used to request distributed  archive seismological
data. Today  it gives you access  to several European  data archives (European
Integrated Data Archive - EIDA)  that are supporting the protocol developed by
GEOFON   (geofon_dc@gfz-potsdam.de)  at   the   GeoForschungZentrum,  Potsdam,
Germany.

You can find more information about it at the SeisComp3 and GEOFON web pages:

 * http://www.seiscomp3.org/
 * http://geofon.gfz-potsdam.de/ 

ArcLink Password File (for decryption)
======================================

In this file (default: dcidpasswords.txt) you can store your private passwords
given by different  data centers. Each data center  that you request encrypted
data will send you a different password.

The format of the  file is really simple: just the data  center ID followed by
the password that you received. One  data center ID and password per line. Any
empty lines or lines starting with # are ignored.

Example:

gfz password1
odc password2
ipgp password3

The data  center ID and password  can be found on  the automatically generated
e-mail that  you received from each  data center. (You will  only receive this
email if  you have been  authorized to download  encrypted data, and  you have
tried to download it.)

Input File Format
=================

ArcLink Fetch  program supports  two different input  formats for  the request
file.  It  supports  the traditional  BREQ  FAST  format,  and its own  native
format. Both formats  contains the same information and  they differ slightly.

Native Format:
--------------

The native format has the following format: 

YYYY,MM,DD,HH,MM,SS YYYY,MM,DD,HH,MM,SS Network Station Channel [Location]

the Channel, Station and Location, can contains wildcards (*) and the Location
field is optional. For matching all locations please use the '*' symbol.

Example:

2010,02,18,12,00,00 2010,02,18,12,10,00 GE WLF BH*
2010,02,18,12,00,00 2010,02,18,12,10,00 GE VSU BH* 00

BREQ FAST Format:
-----------------

The  BREQ FAST  format is  a  standard format  used on  seismology to  request
data. Each header line start with '.' and the request lines have the following
format:

Station Network {Time Start} {Time End} {Number of Channels} N x Channels Location

Time Specification should have the following format: YYYY MM DD HH MM SS.TTTT

Please read more about the BREQ FAST format at:

http://www.iris.edu/manuals/breq_fast.htm

"""
            sys.exit()

    errors = []
    warnings = []
    if options.user == None:
        errors.append("Username required")
    
    if options.output_file == None:
        errors.append("Output file required")
    
    if options.data_format.upper() != "FSEED" and options.rebuild_volume:
        errors.append("-g is only applicable to FSEED format")

    if len(args) == 0:
        errors.append("No request file supplied")
    else:
        for reqfile in args:
            if not os.path.exists(reqfile):
                errors.append("Request file '%s' not found." % reqfile)

    SSLpasswordDict = {}
    if os.path.exists(options.SSLpasswordFile):
        fd = open(options.SSLpasswordFile)
        line = fd.readline()
        while line:
            line = line.strip()
            if line and line[0] != "#":
                try:
                    (dcid, password) = line.split()
                    SSLpasswordDict[dcid] = password
                except ValueError:
                    logs.error(options.SSLpasswordFile + " invalid line: " + line)
                    fd.close()
                    sys.exit()
            line = fd.readline()
    else:
        if options.SSLpasswordFile != parser.defaults['SSLpasswordFile']:
            errors.append("Supplied password file (%s) not found" % options.SSLpasswordFile)
        else:
            warnings.append("Default password file (%s) not found" % options.SSLpasswordFile)


    if len(errors) > 0:
        logs.error("\n** ArcLink Fetch %s **\n" % VERSION)
        parser.print_usage()
        logs.error("Errors detected on the command line:")
        for item in errors:
            logs.error("\t%s" % item)
        print ""

    if len(warnings) > 0:
        logs.debug("Warnings detected on the command line:")
        for item in warnings:
            logs.debug("\t%s" % item)
        print ""

    if len(errors) > 0:
        sys.exit()

    return (SSLpasswordDict, options.address, options.request_format, options.data_format,
      not options.no_resp_dict, options.rebuild_volume, options.proxymode, options.user,
      options.timeout, options.retries, options.output_file, args[0])

def build_filename(encrypted, compressed, req_args):
    endung = ''
    if compressed is True:
        endung = '.bz2'
    elif compressed is None and req_args.has_key("compression"):
        endung = '.bz2'

    if encrypted:
        endung = endung + '.openssl'
    return endung;

def main():
    (SSLpasswordDict, addr, request_format, data_format, resp_dict, rebuild_volume, proxymode, user, timeout, retries, output_file, input_file) = process_options()

    reblock_mseed = False
    use_inventory = False
    use_routing = not proxymode

    req_args = {"compression": "bzip2"}
    
    if data_format.upper() == "MSEED":
        req_type = "WAVEFORM"
        req_args["format"] = "MSEED"

    elif data_format.upper() == "MSEED4K":
        req_type = "WAVEFORM"
        req_args["format"] = "MSEED"
        reblock_mseed = True

    elif data_format.upper() == "FSEED":
        req_type = "WAVEFORM"
        if rebuild_volume:
            req_args["format"] = "MSEED" 
        else:
            req_args["format"] = "FSEED"
    
    elif data_format.upper() == "DSEED":
        req_type = "RESPONSE"
        use_routing = False
    
    elif len(data_format) >= 3 and data_format.upper() == "INVENTORY"[:len(data_format)]:
        req_type = "INVENTORY"
        req_args["instruments"] = "true"
        use_routing = False

    else:
        logs.error("unsupported data format: %s" % (data_format,))
        return 1
    
    if resp_dict:
        req_args["resp_dict"] = "true"
    else:
        req_args["resp_dict"] = "false"
    

    mgr = ArclinkManager(addr, user, socket_timeout=timeout, download_retry=retries)
    req = mgr.new_request(req_type, req_args)

    if request_format == "native":
        parse_native(req, input_file)

    elif request_format == "breqfast":
        parse_breqfast(req, input_file)

    else:
        logs.error("unsupported request format: %s" % (request_format,))
        return 1

    if not req.content:
        logs.error("empty request")
        return 1
    
    wildcards = False
    for i in req.content:
        for j in i[:4]:
            if j.find("*") >= 0 or j.find("?") >= 0:
                wildcards = True
                break

    if rebuild_volume or wildcards:
        use_inventory = True

    try:
        (inv, req_ok, req_noroute, req_nodata) = mgr.execute(req, use_inventory, use_routing)

    except ArclinkError, e:
        logs.error(str(e))
        return

## Better report what was going on
    if verbosity > 1:
        logs.info("\nthe following data requests were sent:\n")
        for req in req_ok:
            show_status(req)

        if req_nodata:
            logs.info("\nthe following entries returned no data:\n")
            req_nodata.dump(sys.stdout)

        if req_noroute:
            logs.info("\nthe following entries could not be routed:\n")
            req_noroute.dump(sys.stdout)
    else:
        if req_nodata:
            logs.info('some requests returned NODATA')

        if req_noroute:
            logs.warning('some requests could not be routed')

        warn = False
        for req in req_ok:
            for vol in req.status().volume:
                for line in vol.line:
                    if (line.size == 0):
                        warn = True
        if warn:
            logs.warning('some lines returned NODATA')

## Prepare to download
    canJoin = True
    volumecount = 0
    
    if req_type == "WAVEFORM" and req_args.get("format") != "MSEED":
        canJoin = False

    for req in req_ok:
        for vol in req.status().volume:
            if (arclink_status_string(vol.status) == "OK" or arclink_status_string(vol.status) == "WARNING") and vol.size > 0:
                volumecount += 1
                if vol.encrypted and (vol.dcid not in SSLpasswordDict):
                    canJoin = False
                if arclink_status_string(vol.status) == "WARNING":
                    logs.warning("\nsome requests returned a Warning status.")

    if volumecount == 0:
        logs.warning("\nnone of the requests returned data.\n")
        return 1
    
    if not canJoin and volumecount > 1:
        logs.warning('cannot merge volumes saving volumes as individual files')

## Download
    if canJoin:
        filename = output_file
        fd_out = open(filename, "wb")
        if rebuild_volume:
            logs.info("rebuilding SEED volume")
            fd_out = SeedOutput(fd_out, inv, resp_dict)
        elif reblock_mseed:
            logs.info("reblocking Mini-SEED data")
            fd_out = MSeed4KOutput(fd_out)

        for req in req_ok:
            for vol in req.status().volume:
                if vol.size == 0 or (arclink_status_string(vol.status) != "OK" and arclink_status_string(vol.status) != "WARNING"):
                    continue
                try:
                    req.download_data(fd_out, vol.id, block=True, purge=False, password=SSLpasswordDict.get(vol.dcid))
                except ArclinkError, e:
                    logs.error('error on downloading request: ' + str(e))
            try:
                req.purge()
            except ArclinkError, e:
                logs.error('error on purging request: ' + str(e))

        fd_out.close()
        logs.warning("saved file: %s" % filename)

    else:
        if rebuild_volume:
            logs.warning('cannot rebuild volume, saving file as received MiniSeed')
        elif reblock_mseed:
            logs.warning('cannot reblock MSEED, saving file as received MiniSeed')
     
        for req in req_ok:
            for vol in req.status().volume:
                if vol.size == 0 or (arclink_status_string(vol.status) != "OK" and arclink_status_string(vol.status) != "WARNING"):
                    continue

                filename = None
                fd_out = None
                try:
                    filename = str("%s.%s.%s" % (output_file, req.id, vol.id))
                    fd_out = open(filename, "wb")
                    req.download_data(fd_out, vol.id, block=True, purge=False, password=SSLpasswordDict.get(vol.dcid))
                    endung = build_filename(req.encStatus, req.decStatus, req_args)
                    if endung is not None:
                        os.rename(filename, filename + endung)
                        filename = filename + endung
                    logs.warning("saved file: %s" % filename)
                    fd_out.close()
                except ArclinkError, e:
                    logs.error('error on downloading request: ' + str(e))
                    filename = None
                    if fd_out is not None and not fd_out.closed:
                        fd_out.close()

            try:
                req.purge()
            except ArclinkError, e:
                logs.error('error on purging request: ' + str(e))

def _debug(s):
    if verbosity > 1:
        print s
        sys.stdout.flush()

def _info(s):
    if verbosity > 0:
        print s
        sys.stdout.flush()

if __name__ == "__main__":
    logs.info = _info
    logs.debug = _debug
    sys.exit(main())
