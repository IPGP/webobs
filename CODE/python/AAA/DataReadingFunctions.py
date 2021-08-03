# -*-coding:Utf-8 -*

# Webobs - 2012-2021 - Institut de Physique du Globe Paris
#
# Autor(s): Lucie Van Nieuwenhuyze
# Based on the research work of Marielle Malfante and Alexis Falcin
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import numpy as np
from os.path import isfile
import os
#import matplotlib.pylab as plt
from datetime import datetime, timedelta
from obspy import UTCDateTime, read
from obspy.clients.seedlink.basic_client import Client as SeedLinkClient
from obspy.clients.arclink.client import Client as ArcLinkClient
from tools import butter_bandpass_filter, filter_data
import requests
import re

import signal
from multiprocessing import Process
import subprocess

def read_datasource(datasource,tStart):
    """ Read datasource
    INPUT:
    - datasource
    - tStart: datetime object
    OUTPUT:
    - request_function: data reading function matching the datasource protocol
    - sourceUrl: url
    """
    if len(datasource.split(";"))==3:
       if tStart>(datetime.today() - timedelta(hours=int(datasource.split(";")[2]))):
           # protocole 1
           source, sourceUrl = datasource.split(";")[0].split("://",1)
       else:
           # protocole 2
           source, sourceUrl = datasource.split(";")[1].split("://",1)
    elif len(datasource.split(";"))==1:
           source, sourceUrl = datasource.split("://",1)
    #dict_source = {'fdsnws':'request_fdsnws', 'slink':'request_slink', 'arclink':'request_arclink'}
    #request_function = dict_source[source] if source in dict_source.keys() else None
    #return request_function, sourceUrl
    source = source if source in ['fdsnws', 'slink', 'arclink'] else None
    return source, sourceUrl

def filtering(config, fs, signature):
    f_min = config.data_to_analyze['filtering']['bandwith']['fmin']
    f_max = config.data_to_analyze['filtering']['bandwith']['fmax']
    butter_order = config.data_to_analyze['filtering']['butter_order']
    if f_min and f_max and butter_order:
        signature = butter_bandpass_filter(signature, f_min, f_max, fs, order=butter_order)
    return signature


def request_fdsnws(config, sourceUrl, tStart, duration, verbatim=0):
    """ Request function using fdsnws-dataselect protocol.
    Gets the signature only, not full signal
    /!\ Signature of this function should not be modified and is similar for all applications (i,e, request_XXX)
    INPUT:
    - config: config dictionnary according to project formating
    - sourceUrl: datasource Url (without protocole) i.e. http://ws.ipgp.fr/fdsnws/dataselect/1/query?
    - tStart: datetime object
    - duration: in sec
    - verbatim
    OUTPUT:
    - signature: numpy array containing the signal read
    - fs: sampling_rate
   NOTE: The portable fdsnws-dataselect (our FDSNWS dataselect server) implementation is not correctly coded to be reach by obspy.client.fdsn.client.
   That is the reason why we have opted to use requests.get.  
    """
    #Send fdsnws-dataselect request
    try:
        year_s = tStart.year
        month_s = tStart.month
        day_s = tStart.day
        hour_s = tStart.hour
        minute_s = tStart.minute
        second_s = tStart.second

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
        url = sourceUrl+stream+'&start='+start+'&end='+end+'&nodata=404'

        if verbatim > 1:
            print("Request:", url)

        r = requests.get(url) #auth= ("user","password")
    except Exception as inst:
        print('Impossible to send request to client ')
        print('--', inst)
        return 0, []
    #Read data
    try:
        filepath =config.tmp_filepath
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

    #filtering if needed
    if config.data_to_analyze['filtering'] :
        signature = filtering(config, fs, signature)
    return fs, signature

def request_slink(config, sourceUrl, slinktool_prgm, tStart, duration, verbatim=0):
    """ Request function using seedlink protocol.
    Gets the signature only, not full signal
    /!\ Signature of this function should not be modified and is similar for all applications (i,e, request_XXX)
    INPUT:
    - config: config dictionnary according to project formating
    - sourceUrl: datasource Url (without protocol)
    - tStart: datetime object
    - duration: in sec
    - verbatim
    OUTPUT:
    - signature: numpy array containing the signal read
    - fs: sampling_rate
    """
   #Send slink request  
   #/opt/webobs/CODE/bin/linux-64/slinktool -S '1T_MTSB:00HHZ' -tw '2021,07,01,22,00,00:2021,07,01,22,00,30' -o /tmp/z.msd rtserver.ipgp.fr:18000
    try:
        year_s = tStart.year
        month_s = tStart.month
        day_s = tStart.day
        hour_s = tStart.hour
        minute_s = tStart.minute
        second_s = tStart.second

        tEnd = tStart + timedelta(seconds=duration)
        year_e = tEnd.year
        month_e = tEnd.month
        day_e = tEnd.day
        hour_e = tEnd.hour
        minute_e = tEnd.minute
        second_e = tEnd.second

        start = str(year_s).zfill(4)+","+str(month_s).zfill(2)+","+str(day_s).zfill(2)+","+str(hour_s).zfill(2)+","+str(minute_s).zfill(2)+","+str(second_s).zfill(2)
        end = str(year_e).zfill(4)+","+str(month_e).zfill(2)+","+str(day_e).zfill(2)+","+str(hour_e).zfill(2)+","+str(minute_e).zfill(2)+","+str(second_e).zfill(2)
        stream = config.data_to_analyze['reading_arguments']['network']+'_'+config.data_to_analyze['reading_arguments']['station']+':'+config.data_to_analyze['reading_arguments']['location']+config.data_to_analyze['reading_arguments']['channel']
        #slinktool command verbatim
        v=''
        if verbatim==1:
            v='-v'
        elif verbatim>1:
            v='-vv'

        command = slinktool_prgm +' '+v+' -d -S '+"'"+ stream+"' -tw '"+start+":"+end+"' -o "+ config.tmp_filepath +" "+ sourceUrl

        if verbatim > 1:
            print("Command:", command)

        # If file already exist it needs to be deleted
        if os.path.isfile(config.tmp_filepath):
        #if os.system('lsof -t '+config.tmp_filepath) !=256: #256=0
            #os.system('kill -9 $(lsof -t '+config.tmp_filepath+')') #Delete file
            #subprocess.Popen('kill -9 $(lsof -t '+config.tmp_filepath+')', shell=True)
            os.remove(config.tmp_filepath) #does not work with the step before because it try to delete the tmp which is consered as an executable while it is executing

        # Slinktool command with timeout
        p = subprocess.Popen(command, stdout=subprocess.PIPE, shell=True)
        p.wait(10) #second

    except subprocess.TimeoutExpired:
        p.kill()
        os.system('kill -9 $(lsof -t '+config.tmp_filepath+')')
        print("Slink request seems to ask an infinite buffer. Check the start of the event and the duration.")
        return 0, []
    except Exception as inst:
        print('Impossible to send slink request ')
        print('--', inst)
        return 0, []

    """
    #Code sending slink request with obspy library (it is too slow to be used in real condition)
    #slink://rtserver.ipgp.fr:18000
    server, port = re.split(':',sourceUrl) 
    try:
        client = SeedLinkClient(server, port=int(port))
    except Exception as inst:
        print('Impossible to reach client ')
        print('--', inst)
        return 0, []

    tStart = UTCDateTime(tStart)
    tEnd = UTCDateTime(tStart + timedelta(seconds=duration))
    try:
        st = client.get_waveforms(  config.data_to_analyze['reading_arguments']['network'],
                                    config.data_to_analyze['reading_arguments']['station'],
                                    config.data_to_analyze['reading_arguments']['location'],
                                    config.data_to_analyze['reading_arguments']['channel'],
                                    tStart, tEnd)
    except Exception as inst:
        print('Reading not possible for data: ', tStart, duration )
        print('--', inst)
        return 0, []
    """
    #Read data
    try:
        st = read(config.tmp_filepath, format='MSEED')
    except Exception as inst:
        print('Reading not possible for data: ', tStart, duration )
        print('--', inst)
        return 0, []

    signature = st[0].data
    fs = st[0].stats['sampling_rate']
    if verbatim>1:
        print('Actual request start date: ',st[0].stats['starttime'],' Theoretical request start date: ', UTCDateTime(tStart))
        print('Actual request end date: ',st[0].stats['endtime'],' Theoretical request end date: ', UTCDateTime(tEnd))


   #filtering if needed
    if config.data_to_analyze['filtering'] :
        signature = filtering(config, fs, signature)

    return fs, signature

def request_arclink(config, sourceUrl, tStart, duration, verbatim=0):
    """ Request function using arclink protocol.
    Gets the signature only, not full signal
    /!\ Signature of this function should not be modified and is similar for all applications (i,e, request_XXX)
    INPUT:
    - config: config dictionnary according to project formating
    - sourceUrl: datasource url (without protocol)
    - tStart: datetime object
    - duration: in sec
    - verbatim
    OUTPUT:
    - signature: numpy array containing the signal read
    - fs: sampling_rate
    """
    #arclink://eida.ipgp.fr:18001?user=sefran3
    host, port,user = re.split(':|\?user=',sourceUrl) 
    try:
        client = ArcLinkClient(user, host=host, port=port)
    except Exception as inst:
        print('Impossible to reach client ')
        print('--', inst)
        return 0, []

    tStart = UTCDateTime(tStart)
    tEnd = UTCDateTime(tStart + timedelta(seconds=duration))
    try:
        st = client.get_waveforms(  config.data_to_analyze['reading_arguments']['network'],
                                    config.data_to_analyze['reading_arguments']['station'],
                                    config.data_to_analyze['reading_arguments']['location'],
                                    config.data_to_analyze['reading_arguments']['channel'],
                                    tStart, tEnd)
    except Exception as inst:
        print('Reading not possible for data: ', tStart, duration )
        print('--', inst)
        return 0, []

    signature = st[0].data
    fs = st[0].stats['sampling_rate']

   #filtering if needed
    if config.data_to_analyze['filtering'] :
        signature = filtering(config, fs, signature)

    return fs, signature


def requestObservation(config, datasource, slinktool_prgm, tStart, duration, verbatim=0):
    """ Request observation function.
    Gets the signature only, not full signal.
    Uses the reading_function to get the full signal.
    - config: config dictionnary according to project formating
    - datasource
    - slinktool_prgm
    - tStart: datetime object
    - duration: in sec
    - verbatim
    OUTPUT:
    - signature: numpy array containing the signal read
    - fs: sampling_rate
    """
    # Reading from online server
    try:
        source, sourceUrl = read_datasource(datasource,tStart)
        if source =='slink':
            return request_slink(config, sourceUrl, slinktool_prgm, tStart, duration, verbatim=verbatim)
        elif source=='fdsnws':
            return request_fdsnws(config, sourceUrl, tStart, duration, verbatim=verbatim)
        elif source=='arclink':
            return request_arclink(config, sourceUrl, tStart, duration, verbatim=verbatim)

    except Exception as inst:
        print("Reading from online server not working")
        print('--', inst)
        print('datasource', datasource, 'tStart', tStart, 'duration', duration, 'verbatim', verbatim, 'config', config)
        return 0,[]


