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

import json
import numpy as np
from os.path import isfile, isdir, dirname
from os import mkdir
from tools import *
from sklearn.model_selection import cross_val_score
from DataReadingFunctions import *
# Cross-validator libraries
from sklearn.model_selection import KFold, RepeatedKFold, RepeatedStratifiedKFold, ShuffleSplit, StratifiedKFold, StratifiedShuffleSplit
# Machine learning algorithms librairieso
from sklearn.ensemble import RandomForestClassifier, AdaBoostClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis, QuadraticDiscriminantAnalysis
from sklearn.naive_bayes import GaussianNB
from sklearn.svm import SVC
from sklearn.neural_network import MLPClassifier

class Config:
    """
    Object containing all configuration information needed for this project
    """

    def __init__(self,root_conf, root_data, tmp_filepath, conf_general_filepath,verbatim=0):
        """
        Initialization method
        """
        self.root_conf = root_conf+'/'
        self.root_data = root_data+'/'
        self.tmp_filepath = tmp_filepath
        self.path = conf_general_filepath
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
        + ',\n <root_conf> %s'%self.root_conf \
        + ',\n <root_data> %s'%self.root_data \
        + ',\n <tmp_filepath> %s'%self.tmp_filepath \
        + ',\n <general> %s'%self.general \
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
        if self.general['analysis_type'] == "sparse_realtime":
            self._checkSparseRealtime()
        else:
            print('problem analysis type is not implemented or included yet')
        # Display information if needed
        if self._verbatim > 0:
            print("Welcome to this automatic classification seismic-events")
            print("Webobs - 2012-2021 - Institut de Physique du Globe Paris")
            print(self)
            print()

        return

    def _read(self):
        """
        Read configuration file stored in self.path.
        /!\ Does not do all checking of what is inside config file, just do the
        reading part
        """
        if not isdir(self.root_conf):
            print("There is no directory at", self.root_conf)
            return

        if not isdir(self.root_data):
            print("There is no directory at", self.root_data)
            return 

        if not isdir(dirname(self.tmp_filepath)+'/'):
            print("There is no folder of path", dirname(self.tmp_filepath)+'/')
            print(self.tmp_filepath)
            return 

        if not isfile(self.path):
            print("There is no file at", self.path)
            return

        conf = json.loads(open(self.path).read())

        if not {'general', 'learning', 'features', 'preprocessing'}.issubset(list(conf.keys())):
            print('configuration file not formated as it should. Please check README.')
            return

        self.general = conf['general']
        self.preprocessing = conf['preprocessing']
        self.learning = conf['learning']
        self.features = conf['features']

    def _check(self):
        """
        check if configuration information that has been read is valid,
        i.e., if path exists, etc.
        """
        # Check GENERAL
        # Project root
        # Analysis type
        if self.general['analysis_type'] not in ["sparse_realtime"]:
            print("self.general['analysis_type'] should be sparse_realtime and is ", self.general['analysis_type'])
            return None
        # Path to specific configuration
        if not isfile(self.root_conf + self.general["specific_config_filename"]):
            print('There is no file at ', self.root_conf + self.general["specific_config_filename"])
            print("Please check configuration file for specific_config_filename")
            return None
        # analyzer subfolder
        if not isdir(self.root_data + self.general["path_to_analyzer"] ):
            mkdir(self.root_data + self.general["path_to_analyzer"])
        # catalogue subfolder
        if not isdir(self.root_data + self.general["path_to_catalogue"] ):
            mkdir(self.root_data + self.general["path_to_catalogue"])

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
        if not isfile(self.root_data+self.general['path_to_catalogue']+self.learning['catalogue_filename']):
            print('No learning configuration file at %s'%self.root_data+self.general['path_to_catalogue']+self.learning['catalogue_filename'])
            return None
        #No need to check analyzer's filename because it is a file created 
        # Check FEATURES
        if not isfile(self.root_conf + self.features['path_features']):
            print('No features configuration file at %s'% self.root_conf + self.features['path_features'])
            return None
        for idx, domain in enumerate(self.features['computation_domains'].split(' ')):
            if (domain not in ['time', 'spectral', 'cepstral']):
                print('Computation domain should be time, spectral or cepstral and is ', domain)
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
        conf = json.loads(open(self.root_conf + self.general["specific_config_filename"]).read())
        self.analysis = conf['analysis']
        self.data_to_analyze = conf["data_to_analyze"]
        self.display = conf["display"]
        return

    def _checkSparseRealtime(self):
        """
        Read the configuration file specific to sparse realtime classification.
        """

        # Check DATA_TO_ANALYZE
        # Signal identification
        if not {'network', 'station', 'location', 'channel'}.issubset(list(self.data_to_analyze['reading_arguments'].keys())):
            print('Specific configuration file not formated as it should.')
            return
        #Filtering

        # Check ANALYSIS
        self.analysis = eval(self.analysis)
        if self.analysis :
            print("config.analysis should be None with usecase 3")
            return None
        # Check DISPLAY
        self.display = eval(self.display)
        if self.display :
            print("config.display should be None with usecase 3")
            return None
