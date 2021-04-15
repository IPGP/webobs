#!/home/osboxes/anaconda3/bin/python

# -*-coding:Utf-8 -*

# Last update: 03/2018 - Marielle MALFANTE
# Contact: marielle.malfante@gipsa-lab.fr (@gmail.com)
# Copyright: Marielle MALFANTE - GIPSA-Lab
# Univ. Grenoble Alpes, CNRS, Grenoble INP, GIPSA-lab, 38000 Grenoble, France

#from pathlib import  Path
#import sys
#path = str(Path(Path(__file__).parent.absolute()).parent.absolute())
#sys.path.insert(0,path)

#import obspy
#import soundfile
#import numpy as np
from os.path import isfile
#import matplotlib.pylab as plt
from datetime import datetime, timedelta
from obspy import UTCDateTime
#from obspy.clients.arclink.client import Client
from tools import filter_data
import requests
from obspy import read

#def read_ubinas(file_path, config, verbatim=0):
#    """ Read Ubinas data.
#    /!\ Signature of this function should not be modified and is similar for all applications (i,e, read_XXX)
#    INPUT:
#    - file_path: to file containing data (.dat here)
#    - config: config dictionnary according to project formating
#    - verbatim
#    OUTPUT:
#    - s: numpy array containing the signal read
#    - fs: sampling_rate
#    - t_start and t_end: as datetime.datetime objects
#    - length_n
#    """
#    # Read and check reading
#    if not isfile(file_path):
#        print("No file at",file_path)
#        return None, None
#    stream = obspy.read(file_path)
#    if len(stream.traces) == 0:
#        if verbatim > 0:
#            print('Could not read ',file_path)
#        return None
#    trace = stream.traces[0]
#    # Get signal and its metadata
#    s = trace.data
#    s_dict = trace.stats
#    # Gets information about recording
#    fs = s_dict['sampling_rate']
#    length_n=s_dict['sac']['npts']
#    if length_n != np.shape(s)[0]:
#        print('problem with signals reading dimensions:', length_n, np.shape(s)[0])
#    d0 = s_dict['starttime']
#    d1 = s_dict['endtime']
#    t_start = datetime.datetime(d0.year,d0.month,d0.day,d0.hour,d0.minute,d0.second)
#    t_end = datetime.datetime(d1.year,d1.month,d1.day,d1.hour,d1.minute,d1.second)
#    # verbatim
#    if verbatim > 1:
#        print("\t%s read"%file_path)
#    return s, fs, t_start, t_end, length_n
def request_merapi_mseedreq(config, tStart, duration, verbatim=0):
    """ Request Merapi function.
    Gets the signature only, not full signal
    /!\ Signature of this function should not be modified and is similar for all applications (i,e, request_XXX)
    INPUT:
    - config: config dictionnary according to project formating
    - tStart: datetime object
    - duration: in sec
    - verbatim
    OUTPUT:
    - signature: numpy array containing the signal read
    - fs: sampling_rate
    """

    try:
        year_s = tStart.year
        month_s = tStart.month
        day_s = tStart.day
        hour_s = tStart.hour
        minute_s = tStart.minute
        second_s = tStart.second

        #using mseedreq
        if config.data_to_analyze['reading_arguments']['request']=='mseedreq':
            t1=str(year_s).zfill(4)+","+str(month_s).zfill(2)+","+str(day_s).zfill(2)+","+str(hour_s).zfill(2)+","+str(minute_s).zfill(2)+","+str(second_s).zfill(2)
            streams = config.data_to_analyze['reading_arguments']['network']+"."+config.data_to_analyze['reading_arguments']['station']+"."+config.data_to_analyze['reading_arguments']['location']+"."+config.data_to_analyze['reading_arguments']['channel']
            url= "http://localhost/cgi-bin/mseedreq.pl?all=2&s3=SEFRAN3&streams="+streams+"&t1="+t1+"&ds="+str(int(duration))

        #using  fdsn
        if config.data_to_analyze['reading_arguments']['request']=='fdsn':
            tEnd = tStart + timedelta(seconds=duration)
            year_e = tEnd.year
            month_e = tEnd.month
            day_e = tEnd.day
            hour_e = tEnd.hour
            minute_e = tEnd.minute
            second_e = tEnd.second
            start = str(year_s).zfill(4)+"-"+str(month_s).zfill(2)+"-"+str(day_s).zfill(2)+"T"+str(hour_s).zfill(2)+":"+str(minute_s).zfill(2)+":"+str(second_s).zfill(2)
            end = str(year_e).zfill(4)+"-"+str(month_e).zfill(2)+"-"+str(day_e).zfill(2)+"T"+str(hour_e).zfill(2)+":"+str(minute_e).zfill(2)+":"+str(second_e).zfill(2)
            stream = 'net='+config.data_to_analyze['reading_arguments']['network']+'&sta='+config.data_to_analyze['reading_arguments']['station']+'&loc='+config.data_to_analyze['reading_arguments']['location']+'&cha='+config.data_to_analyze['reading_arguments']['channel']
            url = 'http://localhost:8080/fdsnws/dataselect/1/query?'+stream+'&start='+start+'&end='+end+'&nodata=404'

        #if verbatim > 1:
        print("Query:", url)

        r = requests.get(url, auth= ("wo",""))
    except Exception as inst:
        print('Impossible to send request to client ')
        print('--', inst)
        return 0, []

    try:
        filepath =config.general['project_root']+config.application['name'].upper()+ config.data_to_analyze['reading_arguments']['tmpfilepath']
        print(r.status_code) 
        if r.status_code == 200:
            with  open(filepath, 'wb') as f:
                f.write(r.content) 
        st = read(filepath)

    except Exception as inst:
        print('Reading not possible for data: ', tStart, duration )
        print('--', inst)
        return 0, []

    signature = st[0].data
    fs = st[0].stats['sampling_rate']

    if eval(config.data_to_analyze['reading_arguments']['filtering']):
        signature = filter_data(signature, fs, config.data_to_analyze['reading_arguments']['filtering_frequency'])

    return fs, signature



#def request_merapi(config, tStart, duration, verbatim=0):
#    """ Request Merapi function.
#    Gets the signature only, not full signal
#    /!\ Signature of this function should not be modified and is similar for all applications (i,e, request_XXX)
#    INPUT:
#    - config: config dictionnary according to project formating
#    - tStart: datetime object
#    - duration: in sec
#    - verbatim
#    OUTPUT:
#    - signature: numpy array containing the signal read
#    - fs: sampling_rate
#    """
#    if verbatim > 1:
#        debug = True
#    else:
#        debug = False
#
#    try:
#        client = Client(user=config.data_to_analyze['reading_arguments']['user'],
#                        host=config.data_to_analyze['reading_arguments']['host'],
#                        port=config.data_to_analyze['reading_arguments']['port'],
#                        debug=debug)
#    except Exception as inst:
#        print('Impossible to reach client ')
#        print('--', inst)
#        return 0, []
#
#    delta_t = eval(config.data_to_analyze['reading_arguments']['delta_t'])
#    t = UTCDateTime(tStart)
#
#    try:
#        st = client.get_waveforms(  config.data_to_analyze['reading_arguments']['network'],
#                                    config.data_to_analyze['reading_arguments']['station'],
#                                    config.data_to_analyze['reading_arguments']['location'],
#                                    config.data_to_analyze['reading_arguments']['channel'],
#                                    t-delta_t, min(t+duration, t+config.data_to_analyze['reading_arguments']['max_duration']))
#    except Exception as inst:
#        print('Reading not possible for data: ', t, duration )
#        print('--', inst)
#        return 0, []
#
#    signature = st[0].data
#    fs = st[0].stats['sampling_rate']
#
#    if eval(config.data_to_analyze['reading_arguments']['filtering']):
#        signature = filter_data(signature, fs, config.data_to_analyze['reading_arguments']['filtering_frequency'])
#
#    return fs, signature


def requestObservation(config, tStart, duration, pathToRecording, verbatim=0):
    """ Request observation function.
    Gets the signature only, not full signal.
    Uses the reading_function to get the full signal.
    - config: config dictionnary according to project formating
    - tStart: datetime object
    - duration: in sec
    - pathToRecording: for use with data reading function. None is analysis_type
    is sparse_realtime
    - verbatim
    OUTPUT:
    - signature: numpy array containing the signal read
    - fs: sampling_rate
    """
    # If reading from online server
    if config.general['analysis_type'] == "sparse_realtime":
        request_function = config.data_to_analyze['reading_function']
        return request_function(config, tStart, duration, verbatim=verbatim)

    # If reading from local recordings
    else:
        # Read full recording
        reading_function = config.data_to_analyze['reading_function']
        [data, fs, tStartRecording, tEndRecording, length_n] = reading_function(pathToRecording,config,verbatim=0)
        tStartSignatureInRecording = (tStart - tStartRecording).total_seconds()
        nStartSignatureInRecording = int(tStartSignatureInRecording*fs)
        nEndSignatureInRecording = nStartSignatureInRecording + int(duration*fs)
        signature = data[nStartSignatureInRecording:nEndSignatureInRecording]
        return fs, signature
