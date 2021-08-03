#!/usr/bin/python3

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

from pathlib import  Path
import sys
path = str(Path(Path(__file__).parent.absolute()).parent.absolute())
sys.path.insert(0,path)

from json import dumps
from os.path import isfile, isdir, join
from tools import *
from config import Config
from analyzer import Analyzer
import time
from datetime import datetime
from features import FeatureVector
from os import system
from sklearn.metrics import confusion_matrix, accuracy_score
from sklearn import preprocessing
from DataReadingFunctions import *

def analyzing(root_conf, root_data, tmp_filepath, setting_filename, datasource, slinktool_prgm, year, month, day, hour, minut, second, duration, verbatim):
    # Range of input arguments
    verbatim_range = [0,1,2,3] # O: quiet, 1: settings and main tasks, 2: more details regarding ongoing computation, 3: chats a lot
    datasource_range = ['fdsnws','slink','arclink']

    # Check input arguments
    try:
       root_conf = str(root_conf)
    except:
        print("Path of configuration folder should be a string")
        print(help)
        sys.exit()

    try:
       root_data = str(root_data)
    except:
        print("Path of data folder should be a string")
        print(help)
        sys.exit()

    try:
       tmp_filepath = str(tmp_filepath)
    except:
        print("Temporary file should be a string")
        print(help)
        sys.exit()

    try:
       setting_filename = str(setting_filename)
       conf_general_filepath = join(root_conf,setting_filename)
    except:
        print("Configuration file should be a string")
        print(help)
        sys.exit()

    try:
        datasource = str(datasource)
    except:
        print('Datasource argument should be a string')
        sys.exit()

    source = datasource.split("://")[0]
    if source not in datasource_range:
        print('Datasoure argument should start with : ', datasource_range, 'and is ', source)
        sys.exit()

    try:
        slinktool_prgm = str(slinktool_prgm)
    except:
        print('Slinktool programm argument should be a string')
        sys.exit()

    try:
        year = int(year)
        month = int(month)
        day = int(day)
        hour = int(hour)
        minut = int(minut)
        second = float(second)
    except:
        print('Year, month, day, hour, minut  should be int and second should be int or float ')
        print(help)
        sys.exit()

    try:
        duration = float(duration)
    except:
        print('Duration should be int or float and is ', duration)
        print(help)
        sys.exit()

    try:
        verbatim = int(verbatim)
    except:
        print('Verbatim argument should be an int and is: ', verbatim)
        sys.exit()

    if verbatim not in verbatim_range:
        print('Verbatim argument should be an between in: ', verbatim_range, 'and is ', verbatim)
        sys.exit()

    try:
        tStartSignature = datetime(year, month, day, hour, minut, int(second), int((second-int(second))*100))
    except Exception as inst:
        print('Problem while reading date or hour : ', year, month, day, hour, minut, second)
        print('--', inst)
        sys.exit()


    # NB: use of verbatim_system to match wanted use in BPPTKG
    #verbatim_system = 0
    #if verbatim > 2:
    #    verbatim_system=1
    verbatim_system = verbatim
    # Init project with configuration file
    try:
       t_start_config = time.time()
       config = Config(root_conf, root_data, tmp_filepath, conf_general_filepath, verbatim=verbatim_system)
       config.readAndCheck()
       t_end_config = time.time()
       if verbatim > 2:
            print('Config step: ', t_end_config - t_start_config, 'sec')
    except Exception as inst:
       print("Config not working")
       print('--', inst)

    # ANALYSIS OF A NEW DATA

    # Make or load analyzer (model+scaler)
    try:
        t_start_analyzer = time.time()
        analyzer = Analyzer(config, verbatim=verbatim_system)
        analyzer.load(config)
        t_end_analyzer = time.time()
        if verbatim > 2:
            print('Analyzer step: ', t_end_analyzer - t_start_analyzer, 'sec')

    except Exception as inst:
        print("Analyzer not working")
        print('--',inst)

    # Analyzing a new data
    try:
        t_start_data = time.time()
        (fs, signature) = requestObservation(config, datasource, slinktool_prgm, tStartSignature, duration, verbatim=verbatim_system)
        t_end_data = time.time()
        if verbatim > 2:
             print('Request data step: ', t_end_data - t_start_data, 'sec')

    except Exception as inst:
        print('Data could not be read')
        print('--', inst)

    # Feature extraction for each data
    try:
        t_start_features = time.time()
        my_feature_vector = FeatureVector(config, verbatim=verbatim_system)
        features = extract_features(config, signature.reshape(1, -1), my_feature_vector, fs)
        t_end_features = time.time()
        if verbatim > 2:
            print('Feature vector has been extracted ', np.shape(features), t_end_features - t_start_features, 'sec')
    except:
        print("Features extraction not working")
    # Scale features and store scaler
    try:
        t_start_scaler = time.time()
        features = analyzer.scaler.transform(features)
        t_end_scaler = time.time()
        if verbatim > 2:
            print('Feature vector has been scaled ', np.shape(features), t_end_scaler - t_start_scaler, 'sec')
    except Exception as inst:
        print("Features scaler not working")
        print("--", inst)

    # Get only the probas:
    try:
        t_start_predict = time.time()
        probas = analyzer.model.predict_proba(features)
        t_end_predict = time.time()
    except Exception as inst:
        print("Prediction not working")
        print("--", inst)
    if verbatim > 1:
        print('Output probabilities are: ', t_end_predict - t_start_predict, 'sec')
    response = {}
    for class_name in analyzer.labelEncoder.classes_ :
       # print('proba', class_name, '\t', probas[0][analyzer.labelEncoder.transform([class_name])[0]])
        response[class_name]=str(probas[0][analyzer.labelEncoder.transform([class_name])[0]])
    response = dumps(response)
    print(response)
    return response


help = 'This usecase can only be used for analyzing: \n' + \
        '\n\targ1: Path to configuration folder' +\
        '\n\targ2: Path to data folder' +\
        '\n\targ3: temporary file path' +\
        '\n\targ4: configuration file path (i.e. settings_15.json) with the configuration file located in config folder' +\
        '\n\targ5: data source and format with following format protocole1;protocol2;delay' +\
        '\n (if in config file the request is mseedreq protocols enabled are slink, arclink. Fdsnws otherwise fdsnws is the only one implemented yet)' +\
        '\n\targ6: slinktool programm' + \
        '\n\targ7: year, with following format yyyy' + \
        '\n\targ8: month, with following format mm' + \
        '\n\targ9: day, with following format dd' + \
        '\n\targ10: hour, with following format hh' + \
        '\n\targ11: minut, with following format mm' + \
        '\n\targ12: second, with following format hh_mm_ss.ss' + \
        '\n\targ13: duration, in seconds (can be int or float)' + \
        '\n\targ14: verbatim, depending on how chatty you want the system to be. Should be in [0,1,2,3]'

if __name__ == '__main__':
# Read input arguments
    try:
        root_conf = sys.argv[1]
        root_data =sys.argv[2]
        tmp_filepath =  sys.argv[3]
        setting_filename = sys.argv[4]
        datasource = sys.argv[5]
        slinktool_prgm = sys.argv[6]
        year = sys.argv[7]
        month = sys.argv[8]
        day = sys.argv[9]
        hour = sys.argv[10]
        minut = sys.argv[11]
        second = sys.argv[12]
        duration = sys.argv[13]
        verbatim = sys.argv[14]
        analyzing(root_conf, root_data, tmp_filepath, setting_filename, datasource, slinktool_prgm, year, month, day, hour, minut, second, duration, verbatim)
    except Exception as inst:
        print(inst)
        print(help)
        print()
        print(sys.argv)
        sys.exit()
