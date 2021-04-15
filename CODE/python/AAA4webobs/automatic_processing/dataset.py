# -*-coding:Utf-8 -*

# Last update: 03/2018 - Marielle MALFANTE
# Contact: marielle.malfante@gipsa-lab.fr (@gmail.com)
# Copyright: Marielle MALFANTE - GIPSA-Lab
# Univ. Grenoble Alpes, CNRS, Grenoble INP, GIPSA-lab, 38000 Grenoble, France

from pathlib import  Path
import sys
path = str(Path(Path(__file__).parent.absolute()).parent.absolute())
sys.path.insert(0,path)

import numpy as np
import glob
import datetime
from recording import Recording
from sklearn.metrics import confusion_matrix, accuracy_score
from tools import print_cm
from os.path import isfile
from os import remove, rename
import time


class Dataset:
    """
    Class used to represent a dataset of recordings that need analyzing.
    It simply contains a list of files to analyze.
    - files: list of files to analyze
    - n_files: number of files to analyze
    - verbatim (0 to 3)
    The Recording class is used to perform the analysis on the various files,
    but no attribute is of type Recording.
    """

    def __init__(self, config, verbatim=0):
        """
        Initialization method
        """
        # Get all files to analyze from congif files
        path = config.data_to_analyze['path_to_data'] + config.data_to_analyze['data_files']
        self.files = glob.glob(path)
        self.n_files = len(self.files)
        self._verbatim = verbatim
        if verbatim>0:
            print('\n\n *** DATASET ***')
            print("Path to file to analyze:", self.files)
            print("%d files to analyze."%len(self.files))
        return

    def __repr__(self):
        """
        Representation method (transform the object to str for display)
        """
        s = 'Dataset object with <n_files> %d files'%self.n_files
        return s

    def analyze(self, analyzer, config, save=True):
        """
        Function analyzing all files of the dataset.
        Each file is dealt with as a Recording object, created, analyzed and
        saved.
        See Recording.analyze for more info.
        """
        if self._verbatim > 0:
            print('\n\n *** DATASET ANALYSIS ***')
        tStartGlobal = time.time()
        for file_path in self.files:
            recording = Recording(file_path, config, verbatim=self._verbatim)
            tStart = time.time()
            recording.analyze(analyzer, config)
            tEnd = time.time()
            if self._verbatim>1:
                print('\tRecording has been analyzed', file_path, tEnd-tStart)
            if save:
                recording.save(config)
                if self._verbatim>1:
                    print('\tRecording has been saved')
        tEndGlobal = time.time()
        if self._verbatim>0:
            print('Dataset has been analyzed', tEndGlobal-tStartGlobal)
        return

    def makeDecision(self, config, save=True):
        """
        Function making the decision upon the predicted probas from analyze
        method.
        Each file is dealt with as a Recording object, created, loaded,
        decisions are made, and saved again.
        See Recording.makeDecision for more info.
        """
        if self._verbatim > 0:
            print('\n\n *** DATASET ANALYSIS: MAKING DECISION ON PREDICTIONS ***')
        tStartGlobal = time.time()
        for file_path in self.files:
            recording = Recording(file_path, config, verbatim=self._verbatim)
            recording.load(config)
            tStart = time.time()
            recording.makeDecision(config)
            tEnd = time.time()
            if save:
                recording.save(config)
            if self._verbatim>1:
                print('\tRecording has been re-analyzed: decisions on predictions have been made', file_path, tEnd-tStart)
        tEndGlobal = time.time()
        if self._verbatim>0:
            print('Dataset has been re-analyzed: decisions on predictions have been made', tEndGlobal-tStartGlobal)
        return

    def display(self, config, onlineDisplay=False,saveDisplay=True, forChecking=False, labelEncoder=None):
        """
        Function displaying all files of the dataset.
        Each file is dealt with as a Recording object, created and displayed.
        See Recording.analyze for more info.
        labelEncoder is only needed if forChecking.
        forChecking creates a file per observation and sort them in class by
        class folders that the expert can then review.
        Check README for more information.
        """
        if self._verbatim > 0:
            print('\n\n *** DATASET DISPLAY ***')
        tStartGlobal = time.time()
        for file_path in self.files:
            recording = Recording(file_path, config, verbatim=self._verbatim)
            recording.load(config)
            tStart = time.time()
            recording.display(config, onlineDisplay=onlineDisplay, saveDisplay=saveDisplay, forChecking=forChecking, labelEncoder=labelEncoder)
            tEnd = time.time()
            if self._verbatim>1:
                print('\tRecording has been loaded and displayed', file_path, tEnd-tStart)
        tEndGlobal = time.time()
        if self._verbatim>0:
            print('Dataset has been displayed', tEndGlobal-tStartGlobal)
        return

    def getNumericalResults(self, config, labelEncoder):
        """
        Compute confusion matrix on the analysis that was performed.
        Obviously manual confirmation of all prediction was needed ... hope you enjoyed it ;)
        (that is the goal of display forChecking, where all observation are
        sorted depending on their predicted class, and then reviewed by the
        expert <-- that would probably be you)
        """
        if self._verbatim > 0:
            print('\n\n *** DATASET RESULTS ANALYSIS ***')
        n_considered = 0
        n_not_ok = 0
        path = config.general['project_root'] + config.application['name'].upper() + '/' + config.general['path_to_res'] + config.configuration_number + '/' + config.general['path_to_res_to_review']
        pathToPredictedLabels = path + 'to_review/'
        pathToTrueLabels = path + 'reviewed/'
        predictedLabels = list()
        trueLabels = list()
        folder_list = glob.glob(pathToPredictedLabels+'*/')
        PC = list(labelEncoder.classes_) + ['unknown']
        p = pathToTrueLabels+'__unknown/*.png'
        p2 = pathToTrueLabels+'__unknown/*/*.png'
        unsureList = glob.glob(p) + glob.glob(p2)
        unsureList_ = [filePath.split('/')[-1] for filePath in unsureList]
        if len(folder_list) == 0:
            print('Nothing to read', folder_list)
            return None
        # For loop on TO_REVIEW files (ie files sorted by PREDICTED labels)
        for folder_path in folder_list:
            predictedLabel = folder_path.split('/')[-2]
            for example_path in glob.glob(folder_path+'*'):
                file_name = example_path.split('/')[-1]
                path = pathToTrueLabels+predictedLabel+'/'+file_name

                # If true prediction
                if isfile(path):
                    trueLabel = predictedLabel
                    predictedLabels.append(predictedLabel)
                    trueLabels.append(trueLabel)
                    n_considered += 1
                # If wrong prediction
                else:
                    # Find the true label if possible
                    trueLabel = None
                    for potential_class in PC:
                        path = pathToTrueLabels+potential_class+'/'+file_name
                        if isfile(path):
                            trueLabel = potential_class
                            predictedLabels.append(predictedLabel)
                            trueLabels.append(trueLabel)
                            new_name = '/'.join(example_path.split('/')[:-1]) + '/_' + trueLabel + '_' + file_name
                            n_considered += 1
                            break
                    # If not, means that the observation was not labeled or was unsure
                    if not trueLabel:
                        # if file_name in unsureList_:
                        #     n_ok += 1
                        # else:
                        print('THIS IS NOT OK, WHERE IS THIS FILE?', file_name, predictedLabel)
                        n_not_ok += 1
                        # if clean:
                        #     print('file has been removed')
                        #     remove(pathToPredictedLabels+predictedLabel+'/'+file_name)
                        #     n_removed += 1

        if self._verbatim>0:
            print('Dataset labels have been analyzed')
            print(n_not_ok, 'observations have been disregarded, ', n_considered, ' considered ')
            print('Accuracy on the dataset is: ', accuracy_score(trueLabels,predictedLabels))
            print(set(trueLabels), set(predictedLabels))
            CM = confusion_matrix(trueLabels,predictedLabels,labels=PC)
            print('and associated confusion matrix is:')
            print_cm(CM,PC,hide_zeroes=True,max_str_label_size=2,float_display=False)

        return(trueLabels,predictedLabels)
