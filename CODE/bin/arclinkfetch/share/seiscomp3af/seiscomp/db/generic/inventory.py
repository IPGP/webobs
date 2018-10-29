# This file was created by a source code generator:
# genxml2wrap.py 
# Do not modify. Change the definition and
# run the generator again!
#
# (c) 2010 Mathias Hoffmann, GFZ Potsdam
#
#
import genwrap as _genwrap
from seiscomp.db.xmlio import inventory as _xmlio
from seiscomp.db import DBError
#
#


# ---------------------------------------------------------------------------------------
class _StationReference(_genwrap.base_StationReference):
	def __init__(self, myStationGroup, stationID, args):
		_genwrap.base_StationReference.__init__(self)
		self.__dict__.update(args)
		self.__dict__['myStationGroup'] = myStationGroup
		self.__dict__['stationID'] = stationID
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _StationGroup(_genwrap.base_StationGroup):
	def __init__(self, my, code, args):
		_genwrap.base_StationGroup.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['code'] = code
		self.__dict__['object'] = {}
		self.__dict__['stationReference'] = {}

	def insert_stationReference(self, stationID, **args):
		if stationID in self.stationReference:
			raise DBError, "StationReference %s already defined" % stationID
		obj = _StationReference(self, stationID, args)
		self.stationReference[stationID] = obj
		return obj
	def remove_stationReference(self, stationID):
		try:
			del self.stationReference[stationID]
		except KeyError:
			raise DBError, "StationReference [%s] not found" % (stationID)
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _AuxSource(_genwrap.base_AuxSource):
	def __init__(self, myAuxDevice, name, args):
		_genwrap.base_AuxSource.__init__(self)
		self.__dict__.update(args)
		self.__dict__['myAuxDevice'] = myAuxDevice
		self.__dict__['name'] = name
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _AuxDevice(_genwrap.base_AuxDevice):
	def __init__(self, my, name, args):
		_genwrap.base_AuxDevice.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['name'] = name
		self.__dict__['object'] = {}
		self.__dict__['source'] = {}

	def insert_source(self, name, **args):
		if name in self.source:
			raise DBError, "AuxSource %s already defined" % name
		obj = _AuxSource(self, name, args)
		self.source[name] = obj
		return obj
	def remove_source(self, name):
		try:
			del self.source[name]
		except KeyError:
			raise DBError, "AuxSource [%s] not found" % (name)
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _SensorCalibration(_genwrap.base_SensorCalibration):
	def __init__(self, mySensor, serialNumber, channel, start, args):
		_genwrap.base_SensorCalibration.__init__(self)
		self.__dict__.update(args)
		self.__dict__['mySensor'] = mySensor
		self.__dict__['serialNumber'] = serialNumber
		self.__dict__['channel'] = channel
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Sensor(_genwrap.base_Sensor):
	def __init__(self, my, name, args):
		_genwrap.base_Sensor.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['name'] = name
		self.__dict__['object'] = {}
		self.__dict__['calibration'] = {}

	def insert_calibration(self, serialNumber, channel, start, **args):
		if serialNumber not in self.calibration:
			self.calibration[serialNumber] = {}
		if channel not in self.calibration[serialNumber]:
			self.calibration[serialNumber][channel] = {}
		if start in self.calibration[serialNumber][channel]:
			raise DBError, "SensorCalibration [%s][%s][%s] already defined" % (serialNumber, channel, start)
		obj = _SensorCalibration(self, serialNumber, channel, start, args)
		self.calibration[serialNumber][channel][start] = obj
		return obj
	def remove_calibration(self, serialNumber, channel, start):
		try:
			del self.calibration[serialNumber][channel][start]
			if len(self.calibration[serialNumber][channel]) == 0:
				del self.calibration[serialNumber][channel]
			if len(self.calibration[serialNumber]) == 0:
				del self.calibration[serialNumber]
		except KeyError:
			raise DBError, "SensorCalibration [%s][%s][%s] not found" % (serialNumber, channel, start)
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _ResponsePAZ(_genwrap.base_ResponsePAZ):
	def __init__(self, my, name, args):
		_genwrap.base_ResponsePAZ.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['name'] = name
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _ResponsePolynomial(_genwrap.base_ResponsePolynomial):
	def __init__(self, my, name, args):
		_genwrap.base_ResponsePolynomial.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['name'] = name
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _DataloggerCalibration(_genwrap.base_DataloggerCalibration):
	def __init__(self, myDatalogger, serialNumber, channel, start, args):
		_genwrap.base_DataloggerCalibration.__init__(self)
		self.__dict__.update(args)
		self.__dict__['myDatalogger'] = myDatalogger
		self.__dict__['serialNumber'] = serialNumber
		self.__dict__['channel'] = channel
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Decimation(_genwrap.base_Decimation):
	def __init__(self, myDatalogger, sampleRateNumerator, sampleRateDenominator, args):
		_genwrap.base_Decimation.__init__(self)
		self.__dict__.update(args)
		self.__dict__['myDatalogger'] = myDatalogger
		self.__dict__['sampleRateNumerator'] = sampleRateNumerator
		self.__dict__['sampleRateDenominator'] = sampleRateDenominator
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Datalogger(_genwrap.base_Datalogger):
	def __init__(self, my, name, args):
		_genwrap.base_Datalogger.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['name'] = name
		self.__dict__['object'] = {}
		self.__dict__['calibration'] = {}
		self.__dict__['decimation'] = {}

	def insert_calibration(self, serialNumber, channel, start, **args):
		if serialNumber not in self.calibration:
			self.calibration[serialNumber] = {}
		if channel not in self.calibration[serialNumber]:
			self.calibration[serialNumber][channel] = {}
		if start in self.calibration[serialNumber][channel]:
			raise DBError, "DataloggerCalibration [%s][%s][%s] already defined" % (serialNumber, channel, start)
		obj = _DataloggerCalibration(self, serialNumber, channel, start, args)
		self.calibration[serialNumber][channel][start] = obj
		return obj
	def remove_calibration(self, serialNumber, channel, start):
		try:
			del self.calibration[serialNumber][channel][start]
			if len(self.calibration[serialNumber][channel]) == 0:
				del self.calibration[serialNumber][channel]
			if len(self.calibration[serialNumber]) == 0:
				del self.calibration[serialNumber]
		except KeyError:
			raise DBError, "DataloggerCalibration [%s][%s][%s] not found" % (serialNumber, channel, start)

	def insert_decimation(self, sampleRateNumerator, sampleRateDenominator, **args):
		if sampleRateNumerator not in self.decimation:
			self.decimation[sampleRateNumerator] = {}
		if sampleRateDenominator in self.decimation[sampleRateNumerator]:
			raise DBError, "Decimation [%s][%s] already defined" % (sampleRateNumerator, sampleRateDenominator)
		obj = _Decimation(self, sampleRateNumerator, sampleRateDenominator, args)
		self.decimation[sampleRateNumerator][sampleRateDenominator] = obj
		return obj
	def remove_decimation(self, sampleRateNumerator, sampleRateDenominator):
		try:
			del self.decimation[sampleRateNumerator][sampleRateDenominator]
			if len(self.decimation[sampleRateNumerator]) == 0:
				del self.decimation[sampleRateNumerator]
		except KeyError:
			raise DBError, "Decimation [%s][%s] not found" % (sampleRateNumerator, sampleRateDenominator)
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _ResponseFIR(_genwrap.base_ResponseFIR):
	def __init__(self, my, name, args):
		_genwrap.base_ResponseFIR.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['name'] = name
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _AuxStream(_genwrap.base_AuxStream):
	def __init__(self, mySensorLocation, code, start, args):
		_genwrap.base_AuxStream.__init__(self)
		self.__dict__.update(args)
		self.__dict__['mySensorLocation'] = mySensorLocation
		self.__dict__['code'] = code
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Stream(_genwrap.base_Stream):
	def __init__(self, mySensorLocation, code, start, args):
		_genwrap.base_Stream.__init__(self)
		self.__dict__.update(args)
		self.__dict__['mySensorLocation'] = mySensorLocation
		self.__dict__['code'] = code
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _SensorLocation(_genwrap.base_SensorLocation):
	def __init__(self, myStation, code, start, args):
		_genwrap.base_SensorLocation.__init__(self)
		self.__dict__.update(args)
		self.__dict__['myStation'] = myStation
		self.__dict__['code'] = code
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
		self.__dict__['auxStream'] = {}
		self.__dict__['stream'] = {}

	def insert_auxStream(self, code, start, **args):
		if code not in self.auxStream:
			self.auxStream[code] = {}
		if start in self.auxStream[code]:
			raise DBError, "AuxStream [%s][%s] already defined" % (code, start)
		obj = _AuxStream(self, code, start, args)
		self.auxStream[code][start] = obj
		return obj
	def remove_auxStream(self, code, start):
		try:
			del self.auxStream[code][start]
			if len(self.auxStream[code]) == 0:
				del self.auxStream[code]
		except KeyError:
			raise DBError, "AuxStream [%s][%s] not found" % (code, start)

	def insert_stream(self, code, start, **args):
		if code not in self.stream:
			self.stream[code] = {}
		if start in self.stream[code]:
			raise DBError, "Stream [%s][%s] already defined" % (code, start)
		obj = _Stream(self, code, start, args)
		self.stream[code][start] = obj
		return obj
	def remove_stream(self, code, start):
		try:
			del self.stream[code][start]
			if len(self.stream[code]) == 0:
				del self.stream[code]
		except KeyError:
			raise DBError, "Stream [%s][%s] not found" % (code, start)
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Station(_genwrap.base_Station):
	def __init__(self, myNetwork, code, start, args):
		_genwrap.base_Station.__init__(self)
		self.__dict__.update(args)
		self.__dict__['myNetwork'] = myNetwork
		self.__dict__['code'] = code
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
		self.__dict__['sensorLocation'] = {}

	def insert_sensorLocation(self, code, start, **args):
		if code not in self.sensorLocation:
			self.sensorLocation[code] = {}
		if start in self.sensorLocation[code]:
			raise DBError, "SensorLocation [%s][%s] already defined" % (code, start)
		obj = _SensorLocation(self, code, start, args)
		self.sensorLocation[code][start] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_sensorLocation(self, code, start):
		try:
			del self.sensorLocation[code][start]
			if len(self.sensorLocation[code]) == 0:
				del self.sensorLocation[code]
		except KeyError:
			raise DBError, "SensorLocation [%s][%s] not found" % (code, start)
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class _Network(_genwrap.base_Network):
	def __init__(self, my, code, start, args):
		_genwrap.base_Network.__init__(self)
		self.__dict__.update(args)
		self.__dict__['my'] = my
		self.__dict__['code'] = code
		self.__dict__['start'] = start
		self.__dict__['object'] = {}
		self.__dict__['station'] = {}

	def insert_station(self, code, start, **args):
		if code not in self.station:
			self.station[code] = {}
		if start in self.station[code]:
			raise DBError, "Station [%s][%s] already defined" % (code, start)
		obj = _Station(self, code, start, args)
		self.station[code][start] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_station(self, code, start):
		try:
			del self.station[code][start]
			if len(self.station[code]) == 0:
				del self.station[code]
		except KeyError:
			raise DBError, "Station [%s][%s] not found" % (code, start)
# ---------------------------------------------------------------------------------------




# ---------------------------------------------------------------------------------------
class Inventory(object):
	def __init__(self):
		self.__dict__['object'] = {}
		self.__dict__['stationGroup'] = {}
		self.__dict__['auxDevice'] = {}
		self.__dict__['sensor'] = {}
		self.__dict__['datalogger'] = {}
		self.__dict__['responsePAZ'] = {}
		self.__dict__['responseFIR'] = {}
		self.__dict__['responsePolynomial'] = {}
		self.__dict__['network'] = {}

	def insert_stationGroup(self, code, **args):
		if code in self.stationGroup:
			raise DBError, "StationGroup %s already defined" % code
		obj = _StationGroup(self, code, args)
		self.stationGroup[code] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_stationGroup(self, code):
		try:
			del self.stationGroup[code]
		except KeyError:
			raise DBError, "StationGroup [%s] not found" % (code)

	def insert_auxDevice(self, name, **args):
		if name in self.auxDevice:
			raise DBError, "AuxDevice %s already defined" % name
		obj = _AuxDevice(self, name, args)
		self.auxDevice[name] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_auxDevice(self, name):
		try:
			del self.auxDevice[name]
		except KeyError:
			raise DBError, "AuxDevice [%s] not found" % (name)

	def insert_sensor(self, name, **args):
		if name in self.sensor:
			raise DBError, "Sensor %s already defined" % name
		obj = _Sensor(self, name, args)
		self.sensor[name] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_sensor(self, name):
		try:
			del self.sensor[name]
		except KeyError:
			raise DBError, "Sensor [%s] not found" % (name)

	def insert_datalogger(self, name, **args):
		if name in self.datalogger:
			raise DBError, "Datalogger %s already defined" % name
		obj = _Datalogger(self, name, args)
		self.datalogger[name] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_datalogger(self, name):
		try:
			del self.datalogger[name]
		except KeyError:
			raise DBError, "Datalogger [%s] not found" % (name)

	def insert_responsePAZ(self, name, **args):
		if name in self.responsePAZ:
			raise DBError, "ResponsePAZ %s already defined" % name
		obj = _ResponsePAZ(self, name, args)
		self.responsePAZ[name] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_responsePAZ(self, name):
		try:
			del self.responsePAZ[name]
		except KeyError:
			raise DBError, "ResponsePAZ [%s] not found" % (name)

	def insert_responseFIR(self, name, **args):
		if name in self.responseFIR:
			raise DBError, "ResponseFIR %s already defined" % name
		obj = _ResponseFIR(self, name, args)
		self.responseFIR[name] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_responseFIR(self, name):
		try:
			del self.responseFIR[name]
		except KeyError:
			raise DBError, "ResponseFIR [%s] not found" % (name)

	def insert_responsePolynomial(self, name, **args):
		if name in self.responsePolynomial:
			raise DBError, "ResponsePolynomial %s already defined" % name
		obj = _ResponsePolynomial(self, name, args)
		self.responsePolynomial[name] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_responsePolynomial(self, name):
		try:
			del self.responsePolynomial[name]
		except KeyError:
			raise DBError, "ResponsePolynomial [%s] not found" % (name)

	def insert_network(self, code, start, **args):
		if code not in self.network:
			self.network[code] = {}
		if start in self.network[code]:
			raise DBError, "Network [%s][%s] already defined" % (code, start)
		obj = _Network(self, code, start, args)
		self.network[code][start] = obj
		self.object[obj.publicID] = obj
		return obj
	def remove_network(self, code, start):
		try:
			del self.network[code][start]
			if len(self.network[code]) == 0:
				del self.network[code]
		except KeyError:
			raise DBError, "Network [%s][%s] not found" % (code, start)

	def clear_instruments(self):
		self.stationGroup = {}
		self.auxDevice = {}
		self.sensor = {}
		self.datalogger = {}
		self.responsePAZ = {}
		self.responseFIR = {}
		self.responsePolynomial = {}

	def clear_stations(self):
		self.network = {}

	def load_xml(self, src):
		_xmlio.xml_in(self, src)

	def save_xml(self, dest, instr=0, modified_after=None, stylesheet=None):
		_xmlio.xml_out(self, dest, instr, modified_after, stylesheet)

	def make_parser(self):
		return _xmlio.make_parser(self)
# ---------------------------------------------------------------------------------------





