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


# Last update: 03/2018 - Marielle MALFANTE

from os.path import isfile
from featuresFunctions import *
from tools import bestFFTlength
import json


class FeatureVector:
    """
    Feature vector object to compute and store features values for a given signal
    A feature vector object can be computed many times for various signals.
    It is a pattern.
    The basic idea is to create a feature vector object as a 'pattern' of features to be computed on a dataset.
    Only one feature vector is create, and it is computed as many times as there are data to analyze.
    - pathToFeatureConfig: path to configuration file. Why do we need this path if the config object is passed as argument in __init__ ???
    - domains: list of domains in which the features are to be cocmputed (as str). I.E. ['time', 'frequeny', 'cepstral']. Is automatically read from onfig object.
    - n_domains: number of domains in whih the features are omputed (len of domains)
    - n_features: number of features to compute IN ONE DOMAIN. /!\ /!\ /!\ /!\ /!\ (value set when _readFeaturesFunctions is called)
    - featuresFunctions: functions needed to compute the features, read from config file when _readFeaturesFunctions is called
    - intermValues: needed intermediate values, factorized to optimize computation times.
    - featuresValues: value of all features, is of size (n_domains*n_features, ), init full of zeros in compute,
    takes actual values when _computation is called in compute.
    - featuresRef: ref of all features, is of size (n_domains*n_features, )
    - featuresOptArguments: opt arguments for each feature function, is of size (n_domains*n_features, ), each element is None or a dict
    - featuresComputationDomains: feature computation domain for each feature, is of size (n_domains*n_features, )
    - _verbatim: how chatty do you want your computer to be?
    - _readFeaturesFunctions: reads the feature vector "pattern" from config files, loads all the function, etc (proper init of the object needed before calling compute)
    """

    def __init__(self,config,verbatim=0):
        """
        Initialization method
        """
        self.pathToFeatureConfig = config.root_conf + config.features['path_features']
        self.domains = config.features['computation_domains'].split(' ')
        self.n_domains = len(self.domains)
        self.n_features = None # /!\ In ONE domain
        self.featuresFunctions = None
        self.intermValues = None
        self.featuresValues = None
        self.featuresRef = None
        self.featuresOptArguments = None
        self.featuresComputationDomains = None
        self._verbatim = verbatim
        self._MFCCFlag = None


        # Read features functions
        self._readFeaturesFunctions()

    def compute(self,signal,fs):
        """
        Compute features from signal, according to configuration information given at __init__
        /!\ signal is already in the proper bandwidth
        """
        # Needed for multi value features computation (MFCC or other btw..)
        if self._MFCCFlag:
            self.featuresValues = np.zeros((self.n_features*self.n_domains,),dtype=float)
            self._MFCCcomputation(signal, fs)
            return

        # Get signals for all domains
        signals = np.zeros((self.n_domains,),dtype=object)
        for i,domain in enumerate(self.domains):
            if domain == 'time':
                signals[i] = signal
            elif domain == 'spectral':
                signals[i] = np.absolute(np.fft.fft(signal, bestFFTlength(len(signal))))
            elif domain == 'cepstral':
                signals[i] = np.absolute(np.fft.fft(np.fft.fft(signal, bestFFTlength(len(signal)))))
            else:
                print('computation domain should be time, spectral or cepstral')
                return
        # Define variables: featuresValues
        self.featuresValues = np.zeros((self.n_features*self.n_domains,),dtype=float)
        # Proceed to actual computation
        self._computation(signals,fs)

    def _readFeaturesFunctions(self):
        """
        Get functions needed to compute features from json file.
        NB: Functions are stored in external file, check README for more info
        """
        # Read features config file
        try:
            #configFeatures = json.load(open(self.pathToFeatureConfig,'rb'))
            configFeatures = json.load(open(self.pathToFeatureConfig,'r'))
        except Exception as inst:
            print("Reading json file of features not working")
            print("--", inst)

        # Check that mfcc (or any other multidim feature functions) are not in the list,
        # otherwise deal with it
        featuresFunctionsString = [configFeatures[i_feature]["function"] for i_feature in sorted(list(configFeatures.keys()))]
        if featuresFunctionsString == ['mfcc_vector']:
            iMFCC = sorted(list(configFeatures.keys()))[0]
            featuresFunctionsUnique = eval(configFeatures[iMFCC]["function"])
            featuresOptArgumentsUnique = eval(configFeatures[iMFCC]["function_opt_arg"])
            featuresRefUnique = str(iMFCC)
            self.n_features = featuresOptArgumentsUnique['n_coeff']
            self.featuresRef = np.zeros((self.n_domains*self.n_features,),dtype=object) #TODO: set to MFCC#i
            self.featuresFunctions = featuresFunctionsUnique
            self.featuresOptArguments = featuresOptArgumentsUnique
            self.featuresComputationDomains = np.zeros((self.n_domains*self.n_features,),dtype=object)
            if self.domains != ['time']:
                print('Computation domain should be time only')
                print(self.domains)
                return
            self._MFCCFlag = True
            return

        elif 'mfcc_vector' in featuresFunctionsString:
            print('mfcc should be computed alone (implementation for computation along other features not done yet)')
            return

        # Set right dimensions depending on number of features and number of domains
        self.n_features = len(configFeatures.keys())
        self.featuresRef = np.zeros((self.n_domains*self.n_features,),dtype=object)
        #self.Values will be defined later, during computation
        self.featuresFunctions = np.zeros((self.n_domains*self.n_features,),dtype=object)
        self.featuresOptArguments = np.zeros((self.n_domains*self.n_features,),dtype=object)
        self.featuresComputationDomains = np.zeros((self.n_domains*self.n_features,),dtype=object)

        # Get all featuresFunctions, featuresRef, featuresOptArguments from configFeatures
        # Also set featuresComputationDomains
        # -----> First find them for no specific domain (-> Unique)
        featuresFunctionsUnique = np.zeros((self.n_features,),dtype=object)
        featuresOptArgumentsUnique = np.zeros((self.n_features,),dtype=object)
        featuresRefUnique = np.zeros((self.n_features,),dtype=object)
        for i,i_feature in enumerate(sorted(list(configFeatures.keys()))):
            featuresFunctionsUnique[i] = eval(configFeatures[i_feature]["function"])
            featuresOptArgumentsUnique[i] = eval(configFeatures[i_feature]["function_opt_arg"])
            featuresRefUnique[i] = str(i_feature)
        # -----> Then extend to all domains
        for i,domain in enumerate(self.domains):
            self.featuresFunctions[i*self.n_features:(i+1)*self.n_features] = featuresFunctionsUnique
            self.featuresOptArguments[i*self.n_features:(i+1)*self.n_features] = featuresOptArgumentsUnique
            self.featuresRef[i*self.n_features:(i+1)*self.n_features] = [domain[0]+f for f in featuresRefUnique]
            self.featuresComputationDomains[i*self.n_features:(i+1)*self.n_features] = [domain[0].upper()]*self.n_features

    def _intermComputation(self,signal_in_domain,fs):
        """
        Proceed to interm computation in one domain. Interm values are needed
        before computation (computation factorization)
        - signal_in_domain : shape (length,) contains signal in the needed domain
        - fs: sampling frequency
        """
        # /!\ intermValues for ONE domain. Need to recompute for each domain.
        self.intermValues = dict()

        # Interm values computation.
        self.intermValues['fs'] = fs
        self.intermValues['u'] = np.linspace(0, (len(signal_in_domain) - 1)*(1/fs), len(signal_in_domain))
        self.intermValues['E_u'] = energy_u(signal_in_domain, self.intermValues)
        self.intermValues['E'] = energy(signal_in_domain, self.intermValues)
        self.intermValues['u_bar'] = u_mean(signal_in_domain, self.intermValues)
        self.intermValues['RMS_u'] = RMS_u(signal_in_domain, self.intermValues)

    def _computation(self,signals,fs):
        """
        Compute featuresValues associated to self FeatureVector pattern
        - signals : shape (n_domains,) contains signals in all the domains
        - self.featuresValues is defined and set in this function
        """
        for i,domain in enumerate(self.domains):
            # Compute needed interm values (needed for computation)
            self._intermComputation(signals[i],fs)
            # Compute each feature value
            for j in range(self.n_features): #i*n_features + j -est features.py
                # If there already is a dictionnary of optional arguments, copy
                # and update it with interm values. Then compute feature.
                if self.featuresOptArguments[i*self.n_features + j]:
                    new_dictionary = self.intermValues.copy()
                    new_dictionary.update(self.featuresOptArguments[i*self.n_features + j])
                    self.featuresValues[i*self.n_features + j] = self.featuresFunctions[i*self.n_features + j](signals[i],new_dictionary)
                # Otherwise directly compute feature value.
                else:
                    self.featuresValues[i*self.n_features + j] = self.featuresFunctions[i*self.n_features + j](signals[i],self.intermValues)

    def _MFCCcomputation(self, signal, fs):
        """
        Compute MFCC features. Computation need to be different because one function and several features. Domains should be time only.
        """
        new_dictionary = self.featuresOptArguments.copy()
        new_dictionary.update({'fs':fs})
        mfccs = self.featuresFunctions(signal, arg_dict=new_dictionary)
        self.featuresValues = mfccs
