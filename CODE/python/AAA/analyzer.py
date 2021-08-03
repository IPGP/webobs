
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
from os.path import isfile, isdir
import datetime
from features import FeatureVector
import pickle
import numpy as np
from DataReadingFunctions import requestObservation
from sklearn import preprocessing
from tools import butter_bandpass_filter, print_cm, print_metrics, extract_features
from featuresFunctions import energy, energy_u
from math import sqrt
from sklearn.metrics import confusion_matrix, accuracy_score, classification_report, precision_recall_fscore_support
from sklearn.model_selection import cross_val_score, StratifiedShuffleSplit
import time
from copy import deepcopy
import pandas as pd

# Cross-validator libraries
from sklearn.model_selection import KFold, RepeatedKFold, RepeatedStratifiedKFold, ShuffleSplit, StratifiedKFold, StratifiedShuffleSplit
# Machine learning algorithms libraries
from sklearn.ensemble import RandomForestClassifier, AdaBoostClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis, QuadraticDiscriminantAnalysis
from sklearn.naive_bayes import GaussianNB
from sklearn.svm import SVC
from sklearn.neural_network import MLPClassifier


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
        self.pathToCatalogue = config.root_data + config.general['path_to_catalogue'] + config.learning['catalogue_filename']
        self.catalogue = pd.read_csv(self.pathToCatalogue, sep="[,;]",engine='python')
        #self.catalogue = pd.read_pickle(open(self.pathToCatalogue,'rb'),compression=None)
        #self.catalogue = pickle.load(open(self.pathToCatalogue,'rb'))
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

    def learn(self, config, datasource,  slinktool_prgm, verbatim=None, forModelSelection=False, sss=None, model=None, featuresIndexes=None, returnData=False):
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
        features = FeatureVector(config, verbatim=verbatim)
        nData = len(self.catalogue.index)
        if returnData:
            allData = np.zeros((nData,),dtype=object)
        allLabels = np.zeros((nData,),dtype=object)
        allFeatures = np.zeros((nData,features.n_domains*features.n_features),dtype=float)
        # Read all labeled signatures (labels+data) from the catalogue, and extract features
        tStart = time.time()
        for i in range(len(self.catalogue.index)):
            if self._verbatim > 2:
                print('Data index: ', i)
            secondFloat = self.catalogue.iloc[i]['second']
            tStartSignature = datetime.datetime(self.catalogue.iloc[i]['year'],     \
                                                self.catalogue.iloc[i]['month'],    \
                                                self.catalogue.iloc[i]['day'],      \
                                                self.catalogue.iloc[i]['hour'],     \
                                                self.catalogue.iloc[i]['minute'],   \
                                                int(secondFloat), \
                                                int((secondFloat-int(secondFloat))*1000000)) #microseconds
            duration = self.catalogue.iloc[i]['length']
            path = self.catalogue.iloc[i]['path']
            (fs, signature) = requestObservation(config, datasource, slinktool_prgm, tStartSignature, duration, verbatim=verbatim)
            # If problem
            if len(signature) < 40:
                if verbatim > 2:
                    print('Data is not considered', tStartSignature)
                allFeatures[i] = None
                allLabels[i] = None
                continue

            if returnData:
                allData[i] = signature

            # Get label and check that it is single label (multi label not supported yet)
            lab = self.catalogue.iloc[i]['class']
            if type(lab) is list:
                print('Multi label not implemented for learning yet')
                return None
            allLabels[i] = lab

            # NB: Filtering is made when reading the data

            # Preprocessing & features extraction
            allFeatures[i] = extract_features(config, signature.reshape(1, -1), features, fs)
        tEnd = time.time()
        if verbatim>0:
            print('Training data have been read and features have been extracted ', np.shape(allFeatures))
            print('Computation time: ', tEnd-tStart)

        # Compress labels and features in case of None values (if reading is empty for example)
        i = np.where(allLabels != np.array(None))[0]
        allFeatures = allFeatures[i]
        allLabels = allLabels[i]
        if returnData:
            allData = allData[i]


        #Saving features and labels for futher analysis
        #savingPath = config.root_data + config.general['path_to_analyzer'] + 'features_0.csv'
        #pd.DataFrame(allFeatures).to_csv(savingPath)
        #savingPath = config.root_data + config.general['path_to_analyzer'] + 'labels_0.csv'
        #pd.DataFrame(allLabels).to_csv(savingPath)

        # Transform labels
        self.labelEncoder = preprocessing.LabelEncoder().fit(allLabels)
        allLabelsStd = self.labelEncoder.transform(allLabels)
        if verbatim>0:
            print('Model will be trained on %d classes'%len(self.labelEncoder.classes_), np.unique(allLabelsStd), self.labelEncoder.classes_)

        # Scale features and store scaler
        self.scaler = preprocessing.StandardScaler().fit(allFeatures)
        allFeatures = self.scaler.transform(allFeatures)
        if verbatim>0:
            print('Features have been scaled')

        # Get model from learning configuration file and learn
        self.model = deepcopy(config.learning['algo'])

        if forModelSelection:
            if model is None:
                pass
            else:
                self.model = model

        tStartLearning = time.time()
        if featuresIndexes is None:
            self.model = self.model.fit(allFeatures, allLabelsStd)
        else:
            self.model = self.model.fit(allFeatures[:,featuresIndexes], allLabelsStd)
        tEndLearning = time.time()

        #  Model Evaluation (a) with score, (b) with X-validation
        if verbatim>0:
            # NB: When model is trained (and evaluated by X-validation or score),
            # threshold is NOT used. Threshold is only used when the 'unknown'
            # class can occur (and this is obvisouly not the case with supervised
            # training)
            print('Model has been trained: ', self.model)
            print('Computation time: ', tEndLearning-tStartLearning)

            if featuresIndexes is None:
                allPredictions = self.model.predict(allFeatures)
            else:
                allPredictions = self.model.predict(allFeatures[:,featuresIndexes])

            # (a) Score evaluation
            print('Model score is: ', accuracy_score(allLabelsStd,allPredictions))
            lab = list(range(len(self.labelEncoder.classes_))) # 'unknown' class not needed.
            CM = confusion_matrix(allLabelsStd,allPredictions,labels=lab, )
            print('and associated confusion matrix is:')
            print_cm(CM, list(self.labelEncoder.classes_),hide_zeroes=True,max_str_label_size=2,float_display=False)

            # (b) X-validation
            sss = config.learning['cv']
            print(sss)
            CM=list()
            acc=list()
            model_Xval = deepcopy(self.model)
            #CMnorm=list()
            class_report = list()
            for (i, (train_index, test_index)) in enumerate(sss.split(allFeatures, allLabelsStd)):
                predictionsStd = model_Xval.fit(allFeatures[train_index], allLabelsStd[train_index]).predict(allFeatures[test_index])
                predictions = self.labelEncoder.inverse_transform(predictionsStd)
                CM.append(confusion_matrix(allLabels[test_index],predictions, labels=self.labelEncoder.classes_))
                acc.append(accuracy_score(allLabels[test_index],predictions))
                #CMnorm.append(confusion_matrix(allLabels[test_index],predictions, labels=self.labelEncoder.classes_, normalize='true'))
                class_report.append(classification_report(allLabels[test_index],predictions,labels=np.unique(predictions), output_dict='true'))

            print('Cross-validation results: ', np.mean(acc)*100, ' +/- ', np.std(acc)*100, ' %')
            print_cm(np.mean(CM, axis=0),self.labelEncoder.classes_,hide_zeroes=True,max_str_label_size=2,float_display=False)
            #print('Cross-validation results normalized regarding the truth :')
            #print_cm(np.mean(CMnorm, axis=0),self.labelEncoder.classes_,hide_zeroes=True,float_display=True)

            print('Metrics report:')
            mean_dict={}
            for label in self.labelEncoder.classes_ :
                mean_dict[label] = {metric : np.mean([dict[label][metric] for dict in class_report if label in dict],axis=0) for metric in ['precision','recall','f1-score', 'support']}

            print_metrics(mean_dict, labels=self.labelEncoder.classes_, metrics=['precision','recall','f1-score','support'])
        if returnData:
            return allData, allLabels
        else:
            return None

    def save(self, config):
        """
        Method used to save the object for later use (depending on the
        application, training can take a while and you might want to save the analyzer)
        """
        savingPath = config.root_data + config.general['path_to_analyzer'] + config.learning['analyzer_filename']
        pickle.dump(self.__dict__,open(savingPath,'wb'),protocol=2)
        if self._verbatim > 0:
            print('Analyzer has been saved at: ', savingPath)
            #print(self.__dict__)
        return

    def load(self, config):
        """
        Method used to load the object.
        """
        verbatim = self._verbatim
        savingPath = config.root_data + config.general['path_to_analyzer'] + config.learning['analyzer_filename']
        tmp_dict = pickle.load(open(savingPath,'rb'))
        #tmp_dict = pd.read_pickle(open(savingPath,'rb'), compression=None)
        self.__dict__.update(tmp_dict)
        self._verbatim = verbatim
        if self._verbatim > 0:
            print('Analyzer has been loaded from: ', savingPath)
        return
