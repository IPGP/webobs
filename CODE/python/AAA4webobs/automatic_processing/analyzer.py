# -*-coding:Utf-8 -*

# Last update: 03/2018 - Marielle MALFANTE
# Contact: marielle.malfante@gipsa-lab.fr (@gmail.com)
# Copyright: Marielle MALFANTE - GIPSA-Lab
# Univ. Grenoble Alpes, CNRS, Grenoble INP, GIPSA-lab, 38000 Grenoble, France

#import json
from os.path import isfile, isdir
#import datetime
#from features import FeatureVector
import pickle
#import numpy as np
#from DataReadingFunctions import requestObservation
#from sklearn import preprocessing
#from tools import butter_bandpass_filter
#from featuresFunctions import energy, energy_u
#from math import sqrt
#from sklearn.metrics import confusion_matrix, accuracy_score
#from sklearn.model_selection import cross_val_score, StratifiedShuffleSplit
#from tools import print_cm
#import time
#from tools import extract_features
from copy import deepcopy
from pandas import read_pickle

class Analyzer:
    """ Object containing the needed tools to analyze a Dataset.
    It contains the features scaler, the model, and the labels encoder,
    and can be used to train a model from supervised data.
    - scaler: None if learn has not been called, the learnt scaler otherwise
    - model: None if learn has not been called, the learnt model otherwise
    - labelEncoder: None if learn has not been called, the label encoder (label proper translation
    to int) otherwise
    - pathToCatalogue: path to the labeling catalogue. /!\ Catalogue should have a definite format.
    Check out README for more information on the catalogue shape.
    - catalogue: loaded catalogue of labels
    - _verbatim: how chatty do you want your Analyze to be?
    """

    def __init__(self, config, verbatim=0):
        """
        Initialization method
        """
        self.scaler = None
        self.model = deepcopy(config.learning['algo'])
        self.labelEncoder = None
        self.pathToCatalogue = config.general['project_root']+config.application['name'].upper()+'/'+config.learning['path_to_catalogue']
        self.catalogue = read_pickle(open(self.pathToCatalogue,'rb'))
        self._verbatim = verbatim
        if self._verbatim>0:
            print('\n\n *** ANALYZER ***')
        return

    def __repr__(self):
        """
        Representation method (transform the object to str for display)
        """
        s = 'Analyzer object with model and scaler being: '+str(self.model)+' and ' +str(self.scaler)
        s += '\nCatalogue is at %s'%self.pathToCatalogue
        return s

    def learn(self, config, verbatim=None, forModelSelection=False, sss=None, model=None, featuresIndexes=None, returnData=False):
        """
        Method to train the analyzer.
        Labeled data are read from the catalogue, the data are preprocessed,
        features are extracted and scaled, and model is trained (with the
        stardard labels).
        All the arguments with default values are for a "non classic" use of
        the analyzer object (model selection for example)
        Return None, but can return the data and labels if specified in returnData.
        """
        if verbatim is None:
            verbatim=self._verbatim

        # Get or define usefull stuff
#        features = FeatureVector(config, verbatim=verbatim)
#        nData = len(self.catalogue.index)
#        if returnData:
#            allData = np.zeros((nData,),dtype=object)
#        allLabels = np.zeros((nData,),dtype=object)
#        allFeatures = np.zeros((nData,features.n_domains*features.n_features),dtype=float)

#        # Read all labeled signatures (labels+data) from the catalogue, and extract features
#        tStart = time.time()
#        for i in range(len(self.catalogue.index)):
#            if self._verbatim > 2:
#                print('Data index: ', i)
#            secondFloat = self.catalogue.iloc[i]['second']
#            tStartSignature = datetime.datetime(self.catalogue.iloc[i]['year'],     \
#                                                self.catalogue.iloc[i]['month'],    \
#                                                self.catalogue.iloc[i]['day'],      \
#                                                self.catalogue.iloc[i]['hour'],     \
#                                                self.catalogue.iloc[i]['minute'],   \
#                                                int(secondFloat), \
#                                                int((secondFloat-int(secondFloat))*1000000)) #microseconds
#            duration = self.catalogue.iloc[i]['length']
#            path = self.catalogue.iloc[i]['path']
#            (fs, signature) = requestObservation(config, tStartSignature, duration, path, verbatim=0)

#            # If problem
#            if len(signature) < 40:
#                if verbatim > 2:
#                    print('Data is not considered', tStartSignature)
#                allFeatures[i] = None
#                allLabels[i] = None
#                continue

#            if returnData:
#                allData[i] = signature
#
#            # Get label and check that it is single label (multi label not supported yet)
#            lab = self.catalogue.iloc[i]['class']
#            if type(lab) is list:
#                print('Multi label not implemented for learning yet')
#                return None
#            allLabels[i] = lab
#
#            # Filtering if needed
#            f_min = self.catalogue.iloc[i]['f0']
#            f_max = self.catalogue.iloc[i]['f1']
#            if f_min and f_max:
#                butter_order = config.analysis['butter_order']
#                signature = butter_bandpass_filter(signature, f_min, f_max, fs, order=butter_order)
#
#            # Preprocessing & features extraction
#            allFeatures[i] = extract_features(config, signature.reshape(1, -1), features, fs)
#
#        tEnd = time.time()
#        if verbatim>0:
#            print('Training data have been read and features have been extracted ', np.shape(allFeatures))
#            print('Computation time: ', tEnd-tStart)
#
#
#        # Compress labels and features in case of None values (if reading is empty for example)
#        i = np.where(allLabels != np.array(None))[0]
#        allFeatures = allFeatures[i]
#        allLabels = allLabels[i]
#        if returnData:
#            allData = allData[i]
#
#        # Transform labels
#        self.labelEncoder = preprocessing.LabelEncoder().fit(allLabels)
#        allLabelsStd = self.labelEncoder.transform(allLabels)
#        if verbatim>0:
#            print('Model will be trained on %d classes'%len(self.labelEncoder.classes_), np.unique(allLabelsStd), self.labelEncoder.classes_)
#
#        # Scale features and store scaler
#        self.scaler = preprocessing.StandardScaler().fit(allFeatures)
#        allFeatures = self.scaler.transform(allFeatures)
#        if verbatim>0:
#            print('Features have been scaled')
#
#        # Get model from learning configuration file and learn
#        self.model = deepcopy(config.learning['algo'])
#
#        if forModelSelection:
#            if model is None:
#                pass
#            else:
#                self.model = model
#
#        tStartLearning = time.time()
#        if featuresIndexes is None:
#            self.model = self.model.fit(allFeatures, allLabelsStd)
#        else:
#            self.model = self.model.fit(allFeatures[:,featuresIndexes], allLabelsStd)
#        tEndLearning = time.time()
#
#        #  Model Evaluation (a) with score, (b) with X-validation
#        if verbatim>0:
#            # NB: When model is trained (and evaluated by X-validation or score),
#            # threshold is NOT used. Threshold is only used when the 'unknown'
#            # class can occur (and this is obvisouly not the case with supervised
#            # training)
#            print('Model has been trained: ', self.model)
#            print('Computation time: ', tEndLearning-tStartLearning)
#
#            if featuresIndexes is None:
#                allPredictions = self.model.predict(allFeatures)
#            else:
#                allPredictions = self.model.predict(allFeatures[:,featuresIndexes])
#
#            # (a) Score evaluation
#            print('Model score is: ', accuracy_score(allLabelsStd,allPredictions))
#            lab = list(range(len(self.labelEncoder.classes_))) # 'unknown' class not needed.
#            CM = confusion_matrix(allLabelsStd,allPredictions,labels=lab)
#            print('and associated confusion matrix is:')
#            print_cm(CM, list(self.labelEncoder.classes_),hide_zeroes=True,max_str_label_size=2,float_display=False)
#
#            # (b) X-validation
#            sss = config.learning['cv']
#            print(sss)
#            CM=list()
#            acc=list()
#            model_Xval = deepcopy(self.model)
#            for (i, (train_index, test_index)) in enumerate(sss.split(allFeatures, allLabelsStd)):
#                predictionsStd = model_Xval.fit(allFeatures[train_index], allLabelsStd[train_index]).predict(allFeatures[test_index])
#                predictions = self.labelEncoder.inverse_transform(predictionsStd)
#                CM.append(confusion_matrix(allLabels[test_index],predictions, labels=self.labelEncoder.classes_))
#                acc.append(accuracy_score(allLabels[test_index],predictions))
#            print('Cross-validation results: ', np.mean(acc)*100, ' +/- ', np.std(acc)*100, ' %')
#            print_cm(np.mean(CM, axis=0),self.labelEncoder.classes_,hide_zeroes=True,max_str_label_size=2,float_display=False)
#
#        if returnData:
#            return allData, allLabels
#        else:
#            return None
#
    def save(self, config):
        """
        Method used to save the object for later use (depending on the
        application, training can take a while and you might want to save the analyzer)
        """
        path = config.general['project_root'] + config.application['name'].upper() + '/res/' + config.configuration_number + '/' + config.general['path_to_res']
        savingPath = path+'analyzer'
        pickle.dump(self.__dict__,open(savingPath,'wb'),2)
        if self._verbatim > 0:
            print('Analyzer has been saved at: ', savingPath)
        return

    def load(self, config):
        """
        Method used to load the object.
        """
        verbatim = self._verbatim
        path = config.general['project_root'] + config.application['name'].upper() + '/res/' + config.configuration_number + '/' + config.general['path_to_res']
        savingPath = path+'analyzer'
        tmp_dict = read_pickle(open(savingPath,'rb'))
        self.__dict__.update(tmp_dict)
        self._verbatim = verbatim
        if self._verbatim > 0:
            print('Analyzer has been loaded from: ', savingPath)
        return

