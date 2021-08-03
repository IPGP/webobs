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
from os.path import join
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

def training(root_conf, root_data, tmp_filepath, setting_filename, datasource, slinktool_prgm, verbatim):
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
        verbatim = int(verbatim)
    except:
        print('Verbatim argument should be an int and is ', verbatim)
        sys.exit()

    if verbatim not in verbatim_range:
        print('Verbatim argument should be between in: ', verbatim_range, 'and is ', verbatim)
        sys.exit()

     # NB: use of verbatim_system to match wanted use in BPPTKG
    #verbatim_system = 0
    #if verbatim > 2:
    #    verbatim_system=1

    verbatim_system = verbatim

    # Init project with configuration file
    try:
       config = Config(root_conf, root_data, tmp_filepath, conf_general_filepath, verbatim=verbatim_system)
       config.readAndCheck()
       print('CONFIG OK')
    except Exception as inst:
       print("config not working")
       print('--', inst)


    # TRAINING
    # Make analyzer (model+scaler)
    try:
        analyzer = Analyzer(config, verbatim=verbatim_system)
        analyzer.learn(config, datasource, slinktool_prgm)
        analyzer.save(config)
    except Exception as inst:
        print("Analyzer not working")
        print('--',inst)

help = 'This usecase can only be used for training: \n' + \
        '\n\targ1: path to configuration folder' +\
        '\n\targ2: path to data folder' +\
        '\n\targ3: temporary file fullpath' +\
        '\n\targ4: configuration file path (i.e. settings_15.json) with the configuration file located in config folder' +\
        '\n\targ5: data source and format with following format protocole1;protocol2;delay' + \
        '\n\targ6: slinktool programm' + \
        '\n\targ7: verbatim, depending on how chatty you want the system to be. Should be in [0,1,2,3]'


if __name__ == '__main__':
# Read input arguments
    try:
        root_conf = sys.argv[1]
        root_data =sys.argv[2]
        tmp_filepath =  sys.argv[3]
        setting_filename = sys.argv[4]
        datasource = sys.argv[5]
        slinktool_prgm = sys.argv[6]
        verbatim = sys.argv[7]
        training(root_conf, root_data, tmp_filepath, setting_filename, datasource, slinktool_prgm, verbatim)
    except Exception as inst:
        print(inst)
        print(help)
        print()
        print(sys.argv)
        sys.exit()
