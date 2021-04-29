#!/home/osboxes/anaconda3/bin/python

# Webobs - 2012-2021 - Institut de Physique du Globe Paris
# 
# Autor(s): Lucie Van Nieuwenhuyze
#
#Acknowledgement(s): Marielle Malfante,  Alexis Falcin
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
#import numpy as np
from os.path import isfile
from tools import *
##from dataset import Dataset
from config import Config
##from recording import Recording
from analyzer import Analyzer
##import pickle
import time
from datetime import datetime
from features import FeatureVector
from os import system
from sklearn.metrics import confusion_matrix, accuracy_score
from sklearn import preprocessing
from DataReadingFunctions import *

def training(setting_file_path, datasource, verbatim):
    # Range of input arguments
    verbatim_range = [0,1,2,3] # O: quiet, 1: settings and main tasks, 2: more details regarding ongoing computation, 3: chats a lot
    datasource_range = ['fdsnws']

    # Check input arguments
    try:
       setting_file_path = str(setting_file_path)
    except:
        print("Configuration file should be a string")
        print(help)
        sys.exit()
    if not isfile(setting_file_path):
        print('There is no file at ', setting_file_path, 'please enter a valid path to a configuration file')
        sys.exit()

    try:
        datasource = str(datasource)
    except:
        print('Datasource argument should be a string')
        sys.exit()

    source = datasource.split("://")[0]
    #print("Datasource",source)
    if source not in datasource_range:
        print('Datasoure argument should start with : ', datasource_range, 'and is ', verbatim)
        sys.exit()

    try:
        verbatim = int(verbatim)
    except:
        print('Verbatim argument should be an int between in: ', verbatim_range)
        sys.exit()

    if verbatim not in verbatim_range:
        print('Verbatim argument should be an int between in: ', verbatim_range, 'and is ', verbatim)
        sys.exit()

     # NB: use of verbatim_system to match wanted use in BPPTKG
    verbatim_system = 0
    if verbatim > 2:
        verbatim_system=1

    # Init project with configuration file
    try:
       config = Config(setting_file_path, verbatim=verbatim_system)
       config.readAndCheck()
       print("Config OK")
    except Exception as inst:
       print("config not working")
       print('--', inst)


    # TRAINING
    # Make analyzer (model+scaler)
    try:
        analyzer = Analyzer(config, verbatim=verbatim_system)
        analyzer.learn(config, datasource, verbatim=verbatim)
        print("Learn finished")
        analyzer.save(config)
        print("Analzer OK")
    except:
        print("Analyzer not working")

help = 'This usecase can only be used for training: \n' + \
        '\n\targ1: configuration file path (i.e. settings_15.json) with the configuration file located in config folder' +\
        '\n\targ2: data source and format with following format protocole1;protocol2;delay' + \
        '\n\targ3: verbatim, depending on how chatty you want the system to be. Should be in [0,1,2,3]'


if __name__ == '__main__':
# Read input arguments
    try:
        setting_file_path = sys.argv[1]
        datasource = sys.argv[2]
        verbatim = sys.argv[3]
        training(setting_file_path, datasource, verbatim)
    except Exception as inst:
        print(inst)
        print(help)
        print()
        print(sys.argv)
        sys.exit()

