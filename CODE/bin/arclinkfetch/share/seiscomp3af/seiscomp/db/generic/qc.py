# This file was created by a source code generator:
# genxml2wrap.py 
# Do not modify. Change the definition and
# run the generator again!
#
# (c) 2010 Mathias Hoffmann, GFZ Potsdam
#
#
import genwrap as _genwrap
from seiscomp.db.xmlio import qc as _xmlio
from seiscomp.db import DBError
#
#


# ---------------------------------------------------------------------------------------
class _QCLog(_genwrap.base_QCLog):
	def __init__(self, my, start, waveformID, args):
		_genwrap.base_QCLog.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['start'] = start
		self.__dict__['waveformID'] = waveformID
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _WaveformQuality(_genwrap.base_WaveformQuality):
	def __init__(self, my, start, waveformID, type, parameter, args):
		_genwrap.base_WaveformQuality.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['start'] = start
		self.__dict__['waveformID'] = waveformID
		self.__dict__['type'] = type
		self.__dict__['parameter'] = parameter
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Outage(_genwrap.base_Outage):
	def __init__(self, my, waveformID, start, args):
		_genwrap.base_Outage.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['waveformID'] = waveformID
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class QualityControl(object):
	def __init__(self):
		self.__dict__['object'] = {}
		self.__dict__['log'] = {}
		self.__dict__['waveformQuality'] = {}
		self.__dict__['outage'] = {}

	def insert_log(self, start, waveformID, **args):
		if start not in self.log:
			self.log[start] = {}
		if waveformID in self.log[start]:
			raise DBError, "QCLog [%s][%s] already defined" % (start, waveformID)
		obj = _QCLog(self, start, waveformID, args)
		self.log[start][waveformID] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_log(self, start, waveformID):
		try:
			del self.log[start][waveformID]
			if len(self.log[start]) == 0:
				del self.log[start]
		except KeyError:
			raise DBError, "QCLog [%s][%s] not found" % (start, waveformID)

	def insert_waveformQuality(self, start, waveformID, type, parameter, **args):
		if start not in self.waveformQuality:
			self.waveformQuality[start] = {}
		if waveformID not in self.waveformQuality[start]:
			self.waveformQuality[start][waveformID] = {}
		if type not in self.waveformQuality[start][waveformID]:
			self.waveformQuality[start][waveformID][type] = {}
		if parameter in self.waveformQuality[start][waveformID][type]:
			raise DBError, "WaveformQuality [%s][%s][%s][%s] already defined" % (start, waveformID, type, parameter)
		obj = _WaveformQuality(self, start, waveformID, type, parameter, args)
		self.waveformQuality[start][waveformID][type][parameter] = obj
		return obj
	def remove_waveformQuality(self, start, waveformID, type, parameter):
		try:
			del self.waveformQuality[start][waveformID][type][parameter]
			if len(self.waveformQuality[start][waveformID][type]) == 0:
				del self.waveformQuality[start][waveformID][type]
			if len(self.waveformQuality[start][waveformID]) == 0:
				del self.waveformQuality[start][waveformID]
			if len(self.waveformQuality[start]) == 0:
				del self.waveformQuality[start]
		except KeyError:
			raise DBError, "WaveformQuality [%s][%s][%s][%s] not found" % (start, waveformID, type, parameter)

	def insert_outage(self, waveformID, start, **args):
		if waveformID not in self.outage:
			self.outage[waveformID] = {}
		if start in self.outage[waveformID]:
			raise DBError, "Outage [%s][%s] already defined" % (waveformID, start)
		obj = _Outage(self, waveformID, start, args)
		self.outage[waveformID][start] = obj
		return obj
	def remove_outage(self, waveformID, start):
		try:
			del self.outage[waveformID][start]
			if len(self.outage[waveformID]) == 0:
				del self.outage[waveformID]
		except KeyError:
			raise DBError, "Outage [%s][%s] not found" % (waveformID, start)

	def clear_logs(self):
		self.qclog = {}

	def clear_outages(self):
		self.outage = {}
	
	def clear_waveform_quality(self):
		self.waveform_quality = {}
	
	def load_xml(self, src):
		_xmlio.xml_in(self, src)

	def save_xml(self, dest, modified_after=None, stylesheet=None):
		_xmlio.xml_out(self, dest, modified_after, stylesheet)

	def make_parser(self):
		return _xmlio.make_parser(self)
# ---------------------------------------------------------------------------------------





