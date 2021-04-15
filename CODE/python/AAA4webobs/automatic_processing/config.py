# -*-coding:Utf-8 -*

# Last update: 03/2018 - Marielle MALFANTE
# Contact: marielle.malfante@gipsa-lab.fr (@gmail.com)
# Copyright: Marielle MALFANTE - GIPSA-Lab
# Univ. Grenoble Alpes, CNRS, Grenoble INP, GIPSA-lab, 38000 Grenoble, France

#from pathlib import  Path
#import sys
#path = str(Path(Path(__file__).parent.absolute()).parent.absolute())
#sys.path.insert(0,path)

import json
import numpy as np
from os.path import isfile, isdir
from os import mkdir
from tools import *
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import cross_val_score, StratifiedShuffleSplit
from sklearn import svm
from DataReadingFunctions import *

class Config:
    """
    Object containing all configuration information needed for this project
    """

    def __init__(self,path,verbatim=0):
        """
        Initialization method
        """
        self.path = path
        self.configuration_number = self.path.split('/')[-1].split('.')[0].split('_')[-1]
        self._verbatim = verbatim
        self.general = None
        self.application = None
        self.preprocessing = None
        self.learning = None
        self.features = None
        self.data_to_analyze = None
        self.analysis = None

    def __repr__(self):
        """
        Representation method (transform the object to str for display)
        """
        s = 'Configuration object from <path> %s'%self.path \
        + ', <configuration_number> %s'%self.configuration_number \
        + ',\n <general> %s'%self.general \
        + ',\n <application> %s'%self.application \
        + ',\n <preprocessing> %s'%self.preprocessing \
        + ',\n <learning> %s'%self.learning \
        + ',\n <features> %s'%self.features \
        + ',\n <data_to_analyze> %s'%self.data_to_analyze \
        + ',\n <analysis> %s'%self.analysis #\
        return s


    def readAndCheck(self):
        """
        Read and check configuration file stored at self.path.
        Will also read and check the more specific configuration file,
        depending on the chosen analysis.
        Please check README file for more information regarding configuration
        files.
        """
        # Read
        self._read()
        # Check general configuration information
        self._check()
        # Read specific config file
        self._readSpecific()
        # Check specific config file
        if self.general['analysis_type'] == "continuous":
            self._checkContinuous()
        elif self.general['analysis_type'] == "sparse_offline":
            self._checkSparseOffline()
        elif self.general['analysis_type'] == "sparse_realtime":
            self._checkSparseRealtime()
        else:
            print('problem')
        # Display information if needed
        if self._verbatim > 0:
            print("Welcome to this automatic analysis architecture")
            print("Copyright: Marielle MALFANTE - GIPSA-Lab")
            print("Univ. Grenoble Alpes, CNRS, Grenoble INP, GIPSA-lab, 38000 Grenoble, France")
            print('\n *** PROJECT CONFIGURATION %s ***  '%self.configuration_number)
            print(self)
            print()

        return

    def _read(self):
        """
        Read configuration file stored in self.path.
        /!\ Does not do all checking of what is inside config file, just do the
        reading part
        """
        if not isfile(self.path):
            print("There is no file at", self.path)
            return

        conf = json.loads(open(self.path).read())

        if not {'general', 'application', 'learning', 'features', 'preprocessing'}.issubset(list(conf.keys())):
            print('configuration file not formated as it should. Please check README.')
            return

        self.general = conf['general']
        self.application = conf['application']
        self.preprocessing = conf['preprocessing']
        self.learning = conf['learning']
        self.features = conf['features']

    def _check(self):
        """
        check if configuration information that has been read is valid,
        i.e., if path exists, etc.
        """
        # Check APPLICATION
        # Make application folder
        if not isdir(self.general['project_root'] + self.application['name'].upper()):
            mkdir(self.general['project_root'] + self.application['name'].upper())
            print('Application directory has been created')
        # With data subfolder
        if not isdir(self.general['project_root'] + self.application['name'].upper() + '/data'):
            mkdir(self.general['project_root'] + self.application['name'].upper() + '/data')
        # With res subfolder
        if not isdir(self.general['project_root'] + self.application['name'].upper() + '/res'):
            mkdir(self.general['project_root'] + self.application['name'].upper() + '/res')
        # With configuration_number subsubfolder
        if not isdir(self.general['project_root'] + self.application['name'].upper() + '/res/' + self.configuration_number):
            mkdir(self.general['project_root'] + self.application['name'].upper() + '/res/' + self.configuration_number)

        # Check GENERAL
        # Project root
        if not isdir(self.general['project_root']):
            print(self.general['project_root'] + "is not a directory and cannot be project root")
            return None
        # Analysis type
        if self.general['analysis_type'] not in ["continuous", "sparse_offline", "sparse_realtime"]:
            print("self.general['analysis_type'] should be continuous, sparse_offline or sparse_realtime and is ", self.general['analysis_type'])
            return None
        # Path to specific analysis
        if not isfile(self.general['project_root'] + self.general["path_to_specific_settings_file"]):
            print('There is no file at ', self.general['project_root'] + self.general["path_to_specific_settings_file"])
            print("Please check configuration file for path_to_specific_settings_file")
            return None
        # Res
        if not isdir(self.general['project_root'] + self.application['name'].upper() + '/res/' + self.configuration_number + '/' + self.general["path_to_res"]):
            mkdir(self.general['project_root'] + self.application['name'].upper() + '/res/' + self.configuration_number + '/' + self.general["path_to_res"])
        # path_to_visuals
        if not isdir(self.general['project_root'] + self.application['name'].upper() + '/res/' + self.configuration_number + '/' + self.general["path_to_visuals"]):
            mkdir(self.general['project_root'] + self.application['name'].upper() + '/res/' + self.configuration_number + '/' + self.general["path_to_visuals"])
        # path_to_res_to_review
        if not isdir(self.general['project_root'] + self.application['name'].upper() + '/res/' + self.configuration_number + '/' + self.general["path_to_res_to_review"]):
            mkdir(self.general['project_root'] + self.application['name'].upper() + '/res/' + self.configuration_number + '/' + self.general["path_to_res_to_review"])
        # Check PREPROCESSING
        self.preprocessing['energy_norm'] = eval(self.preprocessing['energy_norm'])
        if type(self.preprocessing['energy_norm']) != bool:
            print('energy_norm should be True or False and is ', self.preprocessing['energy_norm'])
            return None

        # Check LEARNING:
        try:
            self.learning['algo'] = eval(self.learning['algo'])
        except Exception as inst:
            print("Learning algorithm at config.learning['algo'] could not be found")
            print('--', inst)
            return None
        try:
            self.learning['cv'] = eval(self.learning['cv'])
        except Exception as inst:
            print("X-validation splitting data procedure at config.learning['cv'] could not be found")
            print('--', inst)
            return None
        if not isfile(self.general['project_root']+self.application['name'].upper()+'/'+self.learning['path_to_catalogue']):
            print('No learning configuration file at %s'%self.general['project_root']+self.application['name'].upper()+'/'+self.learning['path_to_catalogue'])
            return None
        # Check FEATURES
        if not isfile(self.general['project_root'] + self.features['path_to_config']):
            print('No features configuration file at %s'% self.general['project_root'] + self.features['path_to_config'])
            return None
        self.features['thresholding'] = eval(self.features['thresholding'])
        if type(self.features['thresholding']) != bool:
            print('config.features[thresholding] should be True or False and is ', self.features['thresholding'])
            return None
        self.features['thresholds'] = eval(self.features['thresholds'])

    def _readSpecific(self):
        """
        Read the configuration file specific to the application.
        """
        conf = json.loads(open(self.general['project_root'] + self.general["path_to_specific_settings_file"]).read())
        self.analysis = conf['analysis']
        self.data_to_analyze = conf["data_to_analyze"]
        self.display = conf["display"]
        return

    def _checkContinuous(self):
        """
        Read the configuration file specific to the application 1.
        """
        # Check DATA_TO_ANALYZE
        # path_to_data
        if not isdir(self.data_to_analyze['path_to_data']):
            print(self.data_to_analyze['path_to_data'], 'does not exists and therefore cannot contain data')
            return None
        # reading_function
        try:
            self.data_to_analyze['reading_function'] = eval(self.data_to_analyze['reading_function'])
        except Exception as inst:
            print("self.data_to_analyze['reading_function'] cannot be found")
            print('--', inst)
            return None

        # Check ANALYSIS
        # n_window
        if type(self.analysis['n_window']) != int:
            print("self.analyze['n_window'] should be int and is",type(self.analysis['n_window']))
            return None
        if self.analysis['n_window'] != 1:
            print("self.analysis['n_window'] supports only 1 window. Multi-scale analysis is not implemented yet. Please change value and relaunch.")
            return None
        # window_length
        self.analysis['window_length'] = eval(self.analysis['window_length'])
        if type(self.analysis['window_length']) != int :
            if type(self.analysis['window_length']) != float:
                print("self.analysis['window_length'] should be an int or float and is",type(self.analysis['window_length']))
                return None

        # delta
        if type(self.analysis['delta']) != int:
            print("self.analysis['delta'] should be of type int and is ", type(self.analysis['delta']))
            return None

        if type(self.analysis['bandwidth']) != dict:
            print("self.analysis['bandwidth'] is not a dict and shoul be (with 2 keys: 'f_min' and 'f_max')")
            return None
        else:
            n1 = len(self.analysis['bandwidth']['f_min'])
            n2 = len(self.analysis['bandwidth']['f_max'])
            if n1 != n2:
                print("self.analysis['bandwidth']['f_min'] and self.analysis['bandwidth']['f_max'] should have same length")
                return None
            else:
                self.analysis['nBands'] = n1

    def _checkSparseOffline(self):
        """
        Read the configuration file specific to the application 2.
        """

        # Check DATA_TO_ANALYZE
        if not isfile(self.data_to_analyze['path_to_learning_data']):
            print('No file for learning data at ', self.data_to_analyze['path_to_learning_data'])
            return None
        if not isfile(self.data_to_analyze['path_to_learning_labels']):
            print('No file for learning labels at ', self.data_to_analyze['path_to_learning_labels'])
            return None
        if not isfile(self.data_to_analyze['path_to_testing_data']):
            print('No file for testing data at ', self.data_to_analyze['path_to_testing_data'])
            return None
        if not isfile(self.data_to_analyze['path_to_testing_labels']):
            print('No file for testing labels at ', self.data_to_analyze['path_to_testing_labels'])
            return None
        if type(self.data_to_analyze['fs']) != int:
            print('fs should be int and is ', type(self.data_to_analyze['fs']))
            return None
        # Check ANALYSIS
        self.analysis = eval(self.analysis)
        if self.analysis :
            print("config.analysis should be None with usecase 2")
            return None

        # Check DISPLAY
        self.display = eval(self.display)
        if self.display :
            print("config.display should be None with usecase 2")
            return None

    def _checkSparseRealtime(self):
        """
        Read the configuration file specific to the application 3.
        """

        # Check DATA_TO_ANALYZE
        # reading_function
        try:
            self.data_to_analyze['reading_function'] = eval(self.data_to_analyze['reading_function'])
        except Exception as inst:
            print("self.data_to_analyze['reading_function'] cannot be found")
            print('--', inst)
            return None

        # Check ANALYSIS
        self.analysis = eval(self.analysis)
        if self.analysis :
            print("config.analysis should be None with usecase 3")
            return None
        # Check DISPLAY
        self.display = eval(self.display)
        if self.display :
            print("config.display should be None with usecase 2")
            return None
