#!/home/osboxes/anaconda3/bin/python

# Last update: 03/2018 - Marielle MALFANTE
# Contact: marielle.malfante@gipsa-lab.fr (@gmail.com)
# Copyright: Marielle MALFANTE - GIPSA-Lab
# Univ. Grenoble Alpes, CNRS, Grenoble INP, GIPSA-lab, 38000 Grenoble, France

from pathlib import  Path
import sys
path = str(Path(Path(__file__).parent.absolute()).parent.absolute())
sys.path.insert(0,path)

from testimport import Testimport

#import json
import numpy as np
from os.path import isfile
from tools import *
#from dataset import Dataset
from config import Config
#from recording import Recording
from analyzer import Analyzer
#import pickle
import time
#import sys
from features import FeatureVector
#from os import system
#from sklearn.metrics import confusion_matrix, accuracy_score
from sklearn import preprocessing
from DataReadingFunctions import *
import datetime

# Range of input arguments
verbatim_range = [0,1,2,3] # O: quiet, 1: settings and main tasks, 2: more details regarding ongoing computation, 3: chats a lot
action_range = ['training', 'analyzing']

#To  re-write
help = 'This usecase can be used for training or analyzing: \n' + \
        'If training:' +\
        '\n\targ1: configuration file path (i.e. settings_15.json) with the configuration file located in config folder' +\
        '\n\targ2: training' +\
        '\n\targ3: verbatim, depending on how chatty you want the system to be. Should be in [0,1,2,3]' + \
        '\n\nIf analyzing:' +\
        '\n\targ1: configuration file path (i.e. settings_15.json) with the configuration file located in config folder' +\
        '\n\targ2: analyzing' +\
        '\n\targ3: date, with following format yyyy_mm_dd' + \
        '\n\targ4: time, with following format hh_mm_ss.ss' + \
        '\n\targ5: duration, in seconds (can be int or float)' + \
        '\n\targ6: verbatim, depending on how chatty you want the system to be. Should be in [0,1,2,3]'

# Read input arguments
action = 'analyzing'
setting_file_path = "/home/wo/webobs/CODE/python/AAA4webobs/config/general/newsettings_31.json"
try:
    year_q = int(sys.argv[1])
    month_q = int(sys.argv[2])
    day_q = int(sys.argv[3])
    hour_q = int(sys.argv[4])
    minut_q = int(sys.argv[5])
    second_q = float(sys.argv[6]) 
    duration = float(sys.argv[7]) 
    verbatim = sys.argv[8]
except:
    print(help)
    print()
    print(sys.argv)
    sys.exit()

#date = str(year_q).zfill(4)+"_"+str(month_q).zfill(2)+"_"+str(day_q).zfill(2)
#time_ = str(hour_q).zfill(2)+"_"+str(minute_q).zfill(2)+"_"+str(int(second_q)).zfill(2)+"."+str(int((second_q-int(second_q))*100))
#date = "2021_03_16"
#time_ = "16_39_34.72"
#duration =  20.92

# Check input arguments
try:
    verbatim = int(verbatim)
except:
    print('Verbatim argument should be an int between in: ', verbatim_range)
    sys.exit()

if verbatim not in verbatim_range:
    print('Verbatim argument should be an int between in: ', verbatim_range, 'and is ', verbatim)
    sys.exit()

if action not in action_range:
    print('Action argument should be in: ', action_range, 'and is ', action)
    sys.exit()

if not isfile(setting_file_path):
    print('There is no file at ', setting_file_path, 'please enter a valid path to a configuration file')
    sys.exit()

if action == 'analyzing':
#    try:
#        year,month,day = date.split('_')
#        year = int(year)
#        month = int(month)
#        day = int(day)
#    except:
#        print('Date should be yyyy_mm_dd')
#        print()
#        print(help)
#        sys.exit()
#    try:
#        hour,minut,second = time_.split('_')
#        hour = int(hour)
#        minut = int(minut)
#        second = float(second)
#    except:
#        print('Time should be hh_mm_ss.ss')
#        print()
#        print(help)
#        sys.exit()
    try:
        duration = float(duration)
    except:
        print('Duration should be int or float and is ', duration)
        print()
        print(help)
        sys.exit()
    try:
        tStartSignature = datetime.datetime(year_q, month_q, day_q, hour_q, minut_q, int(second_q), int((second_q-int(second_q))*100))
# datetime.datetime(year_q,month_q,day_q,hour_q,minut_q,int(second_q),int((second_q-int(second_q))*1000000) )
        print('tstart', tStartSignature)
    except Exception as inst:
        print('Problem while reading date or hour : ', year_q, month_q, day_q, hour_q, minut_q, second_q)
        print('--', inst)
        sys.exit()

# If everything is alright
if verbatim > 2 :
    system('clear')
# NB: use of verbatim_system to match wanted use in BPPTKG
verbatim_system = 0
if verbatim > 2:
    verbatim_system=1

try:
    test = Testimport()
    print("Test  import OK")
except:
    print("Test import  not working")

# Init project with configuration file
try:
    #config = Config()
    config = Config(setting_file_path, verbatim=verbatim_system)
    config.readAndCheck()
    print("Config OK")
except:
    print("config not working")



# TRAINING THE MODEL
#if action == 'training':
#    analyzer = Analyzer(config, verbatim=verbatim)
#    analyzer.learn(config)
#    analyzer.save(config)

# ANALYSIS OF A NEW DATA
if action == 'analyzing':
    # Make or load analyzer (model+scaler)
    try:
        analyzer = Analyzer(config, verbatim=verbatim_system)
        analyzer.load(config)
        print("Analzer OK")
    except:
        print("Analyzer not working")

    # Analyzing a new data
    try:
        (fs, signature) = requestObservation(config, tStartSignature, duration, None, verbatim=0)
        #print(fs)
        #print(signature)
        print("Data reading OK")
    except Exception as inst:
        print('Data could not be read')
        print('--', inst)

    # Feature extraction for each data
    try:
        my_feature_vector = FeatureVector(config, verbatim=verbatim_system)
        t_start_features = time.time()
        features = extract_features(config, signature.reshape(1, -1), my_feature_vector, fs)
        t_end_features = time.time()
#   if verbatim > 2:
        print('Feature vector has been extracted ', np.shape(features), t_end_features - t_start_features, 'sec')
        print("Features extraction OK")
    except:
        print("Features extraction not  ok")

    # Scale features and store scaler
    try:
        t_start_scaler = time.time()
        #print("ohhhh", type(analyzer.scaler.transform(features)))
        features = analyzer.scaler.transform(features)
        t_end_scaler = time.time()
    #if verbatim > 2:
        print('Feature vector has been scaled ', np.shape(features), t_end_scaler - t_start_scaler, 'sec')
        #print("Features after scale: ", features)
        print("Features scaler OK")
    except Exception as inst:
        print("Features scaler not OK")
        print("--", inst)

    # Get only the probas:
    try:
        t_start_predict = time.time()
        probas = analyzer.model.predict_proba(features)
        t_end_predict = time.time()
        print("Prediction OK")
    except Exception as inst:
        print("Prediction not OK")
        print("--", inst)
    #    if verbatim > 1:
    print('Output probabilities are: ', t_end_predict - t_start_predict, 'sec')
    for class_name in analyzer.labelEncoder.classes_ :
        print('proba', class_name, '\t', probas[0][analyzer.labelEncoder.transform([class_name])[0]])

#if verbatim > 2:
#    print()
