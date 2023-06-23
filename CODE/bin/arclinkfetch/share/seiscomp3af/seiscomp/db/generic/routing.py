# This file was created by a source code generator:
# genxml2wrap.py 
# Do not modify. Change the definition and
# run the generator again!
#
# (c) 2010 Mathias Hoffmann, GFZ Potsdam
#
#
import genwrap as _genwrap
from seiscomp.db.xmlio import routing as _xmlio
from seiscomp.db import DBError
#
#


# ---------------------------------------------------------------------------------------
class _RouteArclink(_genwrap.base_RouteArclink):
	def __init__(self, myRoute, address, start, args):
		_genwrap.base_RouteArclink.__init__(self)
		self.__dict__.update(args)
		self.__dict__['myRoute'] = myRoute
		self.__dict__['address'] = address
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _RouteSeedlink(_genwrap.base_RouteSeedlink):
	def __init__(self, myRoute, address, args):
		_genwrap.base_RouteSeedlink.__init__(self)
		self.__dict__.update(args)
		self.__dict__['myRoute'] = myRoute
		self.__dict__['address'] = address
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Route(_genwrap.base_Route):
	def __init__(self, my, networkCode, stationCode, locationCode, streamCode, args):
		_genwrap.base_Route.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['networkCode'] = networkCode
		self.__dict__['stationCode'] = stationCode
		self.__dict__['locationCode'] = locationCode
		self.__dict__['streamCode'] = streamCode
		self.__dict__['object'] = {}
		self.__dict__['arclink'] = {}
		self.__dict__['seedlink'] = {}

	def insert_arclink(self, address, start, **args):
		if address not in self.arclink:
			self.arclink[address] = {}
		if start in self.arclink[address]:
			raise DBError, "RouteArclink [%s][%s] already defined" % (address, start)
		obj = _RouteArclink(self, address, start, args)
		self.arclink[address][start] = obj
		return obj
	def remove_arclink(self, address, start):
		try:
			del self.arclink[address][start]
			if len(self.arclink[address]) == 0:
				del self.arclink[address]
		except KeyError:
			raise DBError, "RouteArclink [%s][%s] not found" % (address, start)

	def insert_seedlink(self, address, **args):
		if address in self.seedlink:
			raise DBError, "RouteSeedlink %s already defined" % address
		obj = _RouteSeedlink(self, address, args)
		self.seedlink[address] = obj
		return obj
	def remove_seedlink(self, address):
		try:
			del self.seedlink[address]
		except KeyError:
			raise DBError, "RouteSeedlink [%s] not found" % (address)
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Access(_genwrap.base_Access):
	def __init__(self, my, networkCode, stationCode, locationCode, streamCode, user, start, args):
		_genwrap.base_Access.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['networkCode'] = networkCode
		self.__dict__['stationCode'] = stationCode
		self.__dict__['locationCode'] = locationCode
		self.__dict__['streamCode'] = streamCode
		self.__dict__['user'] = user
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class Routing(object):
	def __init__(self):
		self.__dict__['object'] = {}
		self.__dict__['route'] = {}
		self.__dict__['access'] = {}

	def insert_route(self, networkCode, stationCode, locationCode, streamCode, **args):
		if networkCode not in self.route:
			self.route[networkCode] = {}
		if stationCode not in self.route[networkCode]:
			self.route[networkCode][stationCode] = {}
		if locationCode not in self.route[networkCode][stationCode]:
			self.route[networkCode][stationCode][locationCode] = {}
		if streamCode in self.route[networkCode][stationCode][locationCode]:
			raise DBError, "Route [%s][%s][%s][%s] already defined" % (networkCode, stationCode, locationCode, streamCode)
		obj = _Route(self, networkCode, stationCode, locationCode, streamCode, args)
		self.route[networkCode][stationCode][locationCode][streamCode] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_route(self, networkCode, stationCode, locationCode, streamCode):
		try:
			del self.route[networkCode][stationCode][locationCode][streamCode]
			if len(self.route[networkCode][stationCode][locationCode]) == 0:
				del self.route[networkCode][stationCode][locationCode]
			if len(self.route[networkCode][stationCode]) == 0:
				del self.route[networkCode][stationCode]
			if len(self.route[networkCode]) == 0:
				del self.route[networkCode]
		except KeyError:
			raise DBError, "Route [%s][%s][%s][%s] not found" % (networkCode, stationCode, locationCode, streamCode)

	def insert_access(self, networkCode, stationCode, locationCode, streamCode, user, start, **args):
		if networkCode not in self.access:
			self.access[networkCode] = {}
		if stationCode not in self.access[networkCode]:
			self.access[networkCode][stationCode] = {}
		if locationCode not in self.access[networkCode][stationCode]:
			self.access[networkCode][stationCode][locationCode] = {}
		if streamCode not in self.access[networkCode][stationCode][locationCode]:
			self.access[networkCode][stationCode][locationCode][streamCode] = {}
		if user not in self.access[networkCode][stationCode][locationCode][streamCode]:
			self.access[networkCode][stationCode][locationCode][streamCode][user] = {}
		if start in self.access[networkCode][stationCode][locationCode][streamCode][user]:
			raise DBError, "Access [%s][%s][%s][%s][%s][%s] already defined" % (networkCode, stationCode, locationCode, streamCode, user, start)
		obj = _Access(self, networkCode, stationCode, locationCode, streamCode, user, start, args)
		self.access[networkCode][stationCode][locationCode][streamCode][user][start] = obj
		return obj
	def remove_access(self, networkCode, stationCode, locationCode, streamCode, user, start):
		try:
			del self.access[networkCode][stationCode][locationCode][streamCode][user][start]
			if len(self.access[networkCode][stationCode][locationCode][streamCode][user]) == 0:
				del self.access[networkCode][stationCode][locationCode][streamCode][user]
			if len(self.access[networkCode][stationCode][locationCode][streamCode]) == 0:
				del self.access[networkCode][stationCode][locationCode][streamCode]
			if len(self.access[networkCode][stationCode][locationCode]) == 0:
				del self.access[networkCode][stationCode][locationCode]
			if len(self.access[networkCode][stationCode]) == 0:
				del self.access[networkCode][stationCode]
			if len(self.access[networkCode]) == 0:
				del self.access[networkCode]
		except KeyError:
			raise DBError, "Access [%s][%s][%s][%s][%s][%s] not found" % (networkCode, stationCode, locationCode, streamCode, user, start)

	def clear_routes(self):
		self.route = {}

	def clear_access(self):
		self.access = {}
	
	def load_xml(self, src, use_access=False):
		_xmlio.xml_in(self, src, use_access)

	def save_xml(self, dest, use_access=False, modified_after=None, stylesheet=None):
		_xmlio.xml_out(self, dest, use_access, modified_after, stylesheet)

	def make_parser(self):
		return _xmlio.make_parser(self)

# ---------------------------------------------------------------------------------------





