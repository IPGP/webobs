# -*-coding:Utf-8 -*

# Last update: 03/2018 - Marielle MALFANTE
# Contact: marielle.malfante@gipsa-lab.fr (@gmail.com)
# Copyright: Marielle MALFANTE - GIPSA-Lab
# Univ. Grenoble Alpes, CNRS, Grenoble INP, GIPSA-lab, 38000 Grenoble, France

from pathlib import  Path
import sys
path = str(Path(Path(__file__).parent.absolute()).parent.absolute())
sys.path.insert(0,path)

import datetime
import numpy as np
from DataReadingFunctions import *
from os.path import isfile, isdir
import matplotlib
import pickle
from features import FeatureVector
import scipy.signal as sg
import math
from tools import butter_bandpass_filter, display_observation, getClasses
from featuresFunctions import energy, energy_u
from math import sqrt
from os import mkdir
from sklearn.metrics import confusion_matrix, accuracy_score
import matplotlib.pyplot as plt


class Recording:
    """
    Object describing a recording to be analyzed. All .wav, .dat or other
    recording format will be converted into Recording object
    - path to recording file
    - data
    - fs
    - datetime de t_start
    - datetime de t_end
    - n_length
    """

    def __init__(self,path_to_recording,config,verbatim=0):
        """
        Initialization method
        """
        # If no file
        if not isfile(path=path_to_recording):
            print("No file at %s, recording object could not be created"%path_to_recording)
        # Get reading function which is different for every application
        reading_function = config.data_to_analyze['reading_function']
        self._verbatim = verbatim
        self.path = path_to_recording
        # Read the file
        [self.data, self.fs, self.t_start, self.t_end, self.length_n] = reading_function(path_to_recording,config,verbatim=verbatim)
        # Other stuff
        self.predictedProbas = None # Keeps all the output probabilities
        self.decidedClasses = None  # Keeps only argmax(proba or -1 if unknown). Depends on getClasses function.
        self.associatedProbas = None # Proba associated to the decided class
        if verbatim > 1:
            print("\tRecording has been read and is of shape", np.shape(self.data))

    def __repr__(self):
        """
        Representation method (transform the object to str for display)
        """
        s = 'Recording object of <path> %s, '%self.path + \
        '<fs> %d, '%self.fs + \
        '<t_start> ' + str(self.t_start) + ', <t_end> ' + str(self.t_end) + \
        ', <length_n> %d, '%self.length_n + \
        '<data> and <labels> are of shape ' + str(np.shape(self.data)) + str(np.shape((self.labels)))
        return s

    def analyze(self,analyzer,config,save=True):
        """
        Continuous analyzis of recording object with
        - analyzer: analyzer object with all needed object to conduct the
        analysis
        - config: Configuration object containing the needed configuration
        details for the analysis (window length, etc)
        Results will be stored in self.labels.
        """

        # Local variables
        n_classes = len(analyzer.labelEncoder.classes_)
        window_length_t = config.analysis['window_length']
        delta = config.analysis['delta']
        n_window = config.analysis['n_window']
        n_bands = config.analysis['nBands']
        saving_path = config.general['project_root'] + config.application['name'].upper() + '/'   \
        'res/' + config.configuration_number + '/' + self.path.split('/')[-1] + '__RES.np'
        window_length_n = int(window_length_t * self.fs)
        # Self.predictedProbas is of shape (nBands, nData, nClasses)
        self.predictedProbas = np.array([[[None]*n_classes]*np.shape(self.data)[0]]*n_bands)
        self.decidedClasses = np.array([[None]*np.shape(self.data)[0]]*n_bands)
        self.associatedProbas = np.array([[None]*np.shape(self.data)[0]]*n_bands)

        # Multi-scale analysis not implemented yet
        if n_window != 1:
            print('\tMulti-scale analysis not implemented yet')
            return 1

        # Analyze with sliding window
        # NB: FeatureVector is a pattern of features to be computed again for every new observation to analyze
        features = FeatureVector(config, verbatim=self._verbatim)
        for i_analyzed in range(0,self.length_n,delta):
            # Find signal piece to analyze
            i_start = i_analyzed - int(window_length_n/2)
            i_end = i_analyzed + int(window_length_n/2)
            # If not enough signal to analyze, unknown prediction
            if i_start < 0 or i_end > (self.length_n - 1):
                self.predictedProbas[:,i_analyzed] = [None]*n_classes
                continue # pass the rest of the loop for this iteration

            # Otherwise, get signal, and for each bandwidth: get features and make prediction and store predictions
            # Get signal
            signal = self.data[i_start:i_end]
            # Loop for the various bandwidths
            for i in range(n_bands):
                if self._verbatim > 2:
                    print('\t\tData index: ', i_analyzed, '\tbandwidth: ', i)

                # Filtering:
                f_min = config.analysis['bandwidth']['f_min'][i]
                f_max = config.analysis['bandwidth']['f_max'][i]
                butter_order = config.analysis['butter_order']
                signature = butter_bandpass_filter(signal, f_min, f_max, self.fs, order=butter_order)

                # Preprocessing
                if config.preprocessing['energy_norm']:
                    E = energy(signature, arg_dict={'E_u':energy_u(signature)})
                    signature = signature / sqrt(E)

                # Get features
                features.compute(signature,self.fs)

                # Scale features
                features.featuresValues = analyzer.scaler.transform(features.featuresValues.reshape(1,-1))

                # Make prediction (labels store all probas, predictedClass only the decided one)
                self.predictedProbas[i,i_analyzed] = analyzer.model.predict_proba(features.featuresValues)

        return

    def makeDecision(self, config):
        """
        This method analyses the output probabilities stored in
        self.predictedProbas to decide on the final class (class or unknown).
        The probability associated to the prediction is also stores the
        associated probability.
        NB : This methods can be called if the object has previously been analyzed
        (or analyzed, saved and then loaded)
        """
        (i_, j_, k_) = np.where(self.predictedProbas)
        for [i,j] in np.unique([[i,j] for (i,j) in zip(i_,j_)], axis=0): # DO NOT BREAK THAT LINE ( where only gets rid of the namy None values, but also of the many times when predicted proba = 0 )
            if self._verbatim > 2:
                print('\t\tData index: ', j, '\tbandwidth: ',i)
            a,b = getClasses(self.predictedProbas[i][j].reshape(1,-1), threshold=config.features['thresholds'], thresholding=config.features['thresholding'])
            self.decidedClasses[i][j] = a[0] # Array returned but only one data considered here, so [0]
            self.associatedProbas[i][j] = b[0] # Array returned but only one data considered here, so [0]

    def save(self, config):
        """
        Method used to save the object for later use (depending on the
        application, training can take a while and you might want to save the analyzer)
        """
        path = config.general['project_root'] + config.application['name'].upper() + '/res/' + config.configuration_number + '/' + config.general['path_to_res']
        savingPath = path+self.path.split('/')[-1]+'__res.rec'
        pickle.dump(self.__dict__,open(savingPath,'wb'),2)
        if self._verbatim > 1:
            print('\tRecording has been saved at: ', path)

        return

    def load(self, config):
        """
        Method used to load the object.
        """
        verbatim = self._verbatim
        path = config.general['project_root'] + config.application['name'].upper() + '/res/' + config.configuration_number + '/' + config.general['path_to_res']
        savingPath = path+self.path.split('/')[-1]+'__res.rec'
        tmp_dict = pickle.load(open(savingPath,'rb'))
        self.__dict__.update(tmp_dict)
        self._verbatim = verbatim
        if self._verbatim > 1:
            print('\tRecording has been loaded from: ', path)


    def display(self, config, onlineDisplay=False, saveDisplay=True, forChecking=False, labelEncoder=None):
        """
        Displays prediction results
        """

        if forChecking:
            self._displayForChecking(config, labelEncoder=labelEncoder)
        else:
            self._displayForContinuousAnalysis(config, onlineDisplay=onlineDisplay, saveDisplay=saveDisplay)

    def _displayForChecking(self, config, labelEncoder):
        """
        Save each observation separatly in class by class folders.
        Allows the expert revision of prediction results and accuracy
        measurement of the analysis.
        """

        # Local variables
        n_classes = len(labelEncoder.classes_)
        window_length_t = config.analysis['window_length']
        delta = config.analysis['delta']
        n_window = config.analysis['n_window']
        n_bands = config.analysis['nBands']
        saving_path = config.general['project_root'] + config.application['name'].upper() + '/'   \
        'res/' + config.configuration_number + '/' + self.path.split('/')[-1] + '__RES.np'
        window_length_n = int(window_length_t * self.fs)

        # Make saving folders if they do not exists
        path = config.general['project_root'] + config.application['name'].upper() + '/' + config.general['path_to_res'] + config.configuration_number + '/' + config.general['path_to_res_to_review']
        path1 = path + 'to_review/'
        path2 = path + 'reviewed/'
        if not isdir(path):
            mkdir(path)
        if not isdir(path1):
            mkdir(path1)
        if not isdir(path2):
            mkdir(path2)
        for class_name in labelEncoder.classes_ :
            if not isdir(path1 + class_name + '/'):
                mkdir(path1 + class_name + '/')
        if config.features['thresholding']:
            if not isdir(path1 + 'unknown/'):
                mkdir(path1 + 'unknown/')

        # Displaying of each predicted observation
        for i_analyzed in range(0,self.length_n,delta):
            # Find signal piece to analyze
            i_start = i_analyzed - int(window_length_n/2)
            i_end = i_analyzed + int(window_length_n/2)
            # If not enough signal to analyze, unknown prediction
            if i_start < 0 or i_end > (self.length_n - 1):
                # self.predictedProbas[:,i_analyzed] = [None]*n_classes
                continue # pass the rest of the loop for this iteration

            # Otherwise, get signal, and for each bandwidth: get features and make prediction and store predictions
            # Get signal
            signal = self.data[i_start:i_end]
            # Loop for the various bandwidths
            for i in range(n_bands):
                if self._verbatim > 2:
                    print('\t\tData index: ', i_analyzed, '\tbandwidth: ', i)

                # Filtering, actually no filtering for displaying
                f_min = config.analysis['bandwidth']['f_min'][i]
                f_max = config.analysis['bandwidth']['f_max'][i]
                # butter_order = config.analysis['butter_order']
                # signature = butter_bandpass_filter(signal, f_min, f_max, self.fs, order=butter_order)
                signature = signal

                # Preprocessing
                if config.preprocessing['energy_norm']:
                    E = energy(signature, arg_dict={'E_u':energy_u(signature)})
                    signature = signature / sqrt(E)

                # Get figure title and path
                # Get class name. Technically, should use the encoder and everything, but we don't want to have the analyzer here.
                # Let's keep it that way now, and we'll see if we change it
                class_name = [labelEncoder.inverse_transform(s) if s in range(len(labelEncoder.classes_)) else 'unknown' for s in [self.decidedClasses[i,i_analyzed]]][0]
                # class_name = str(self.decidedClasses[i,i_analyzed])
                s = '_'.join(self.path.split('/')[-1].split('.')[0].split('__')[0].split('_')[1:2])
                t_analyzed = i_analyzed/self.fs
                t_analyzed = np.round(t_analyzed,1)
                figure_title = '%s__%f'%(s,t_analyzed) + '  p(%d)=%f'%(self.decidedClasses[i,i_analyzed],self.associatedProbas[i,i_analyzed])
                figure_title_extended = '%d__%d__%s__%f'%(f_min,f_max, \
                                                    self.path.split('/')[-1].split('.')[0],
                                                    t_analyzed)
                figure_path = path1 + class_name + '/' + figure_title_extended
                # Get spectro signal needed for displaying
                i_start_signal_large = max(0,i_analyzed - int(window_length_n/2) - window_length_n)
                i_end_signal_large = min(i_analyzed + int(window_length_n/2) + window_length_n, self.length_n)
                signal_large = self.data[i_start_signal_large:i_end_signal_large]
                window_size_t = window_length_n / self.fs
                # Display and save the observation
                display_observation(signal_large, f_min, f_max, self.fs, window_size_t, \
                                    config, figure_title, figure_path)

    def _displayForContinuousAnalysis(self, config, onlineDisplay=False, saveDisplay=True):
        """
        Display prediction results with one file per recording object
        TODO: improve & finish
        """
        # Local variables
        n_bands = config.analysis['nBands']

        # Settings
        w_size = config.analysis['spectro_window_size']
        fMax = config.analysis['f_max']
        ratioDecimate = int(self.fs/(2*fMax))

        # Make figure
        fig = plt.figure(figsize=(15,10))
        gs = matplotlib.gridspec.GridSpec(3+n_bands*3,1,height_ratios=[3,2,0.7]+[1,3,0.5]*n_bands)
        # gs = matplotlib.gridspec.GridSpec(3+n_bands*3,1,height_ratios=[3,2,0.7]+[1,3,0.5,1,3])
        # gs = matplotlib.gridspec.GridSpec(3,1,height_ratios=[3,2,0.7])
        # gs = matplotlib.gridspec.GridSpec(2+n_bands*2,1,height_ratios=[3,2]+[1,3]*n_bands)

        # Time vector
        x = np.array([self.t_start + datetime.timedelta(seconds=i/self.fs) for i in range(self.length_n)])

        # SPECTROGRAM
        ax = plt.subplot(gs[0])
        w = sg.kaiser(w_size, 18)
        w = w * w_size / sum([pow(j, 2) for j in w])
        f, time, spec = sg.spectrogram(#sg.decimate(tr.data,4,zero_phase=False),
                                        sg.decimate(self.data,ratioDecimate,zero_phase=False),
                                        fs=self.fs/ratioDecimate,
                                        nperseg=w_size,
                                        noverlap=0.9*w_size,
                                        nfft=1.5*w_size,
                                        window=w,
                                        scaling='density')      # PSD in unit(x)**2/Hz
        spec_db = 10 * np.log10(spec)
        # ax.pcolormesh(time, f, spec_db, shading='flat', vmin=30, vmax=85)
        ax.pcolormesh(time, f, spec_db, shading='gouraud')
        ax.set_ylim((0,fMax))
        # ax.set_xlim((0,self.length_n/self.fs-0.5))
        ax.set_xlim((time[0],time[-1]))
        plt.xticks([])
        plt.yticks(np.linspace(0,fMax,4),size=14)
        plt.ylabel('Freq. (Hz)', size=14)
        plt.title('Signal and spectrogram', size=14)

        # Signal
        ax = plt.subplot(gs[1])
        ax.plot(x,self.data)
        ax.set_ylim((1.1*np.round(np.min(self.data),2),np.round(1.1*np.max(self.data),2)))
        plt.yticks([np.round(np.min(self.data),2),0,np.round(np.max(self.data),2)],size=14)
        plt.ylabel('Amplitude', size=14)
        # ax.xaxis.tick_top()

        # Results on each frequency band
        for i in range(n_bands):
            # Decided classes
            ax = plt.subplot(gs[3+i*n_bands+1*i%2])
            s1 = self.decidedClasses[n_bands-1-i,:].astype(np.double)
            mask1 = np.isfinite(s1)
            (a,)=np.shape(self.decidedClasses[n_bands-1-i,mask1])
            toPlot = np.array(self.decidedClasses[n_bands-1-i,mask1].reshape(1,a),dtype=int)
        #     # lineObjects = ax.pcolor(toPlot, vmin=-1, vmax=5, cmap=Pastel1)
            ax.pcolor(toPlot, cmap='Set1') #vmin=-1, vmax=5,
        #     ax.legend(handles=[line])
        #     ax.set_xlim((0,a))
        #     # ax.set_xlabel('')
        #     # ax.set_xticks([])
        #     ax.set_ylabel('')
        #     ax.set_yticks([])
        #     # title = 'Probability\n' + '(%d-%d Hz)'%(config.analysis['bandwidth']['f_min'][n_bands-1-i],config.analysis['bandwidth']['f_max'][n_bands-1-i])
        #     # plt.ylabel(title, size=14)
        #     if i==0:
        #         # plt.legend(lineObjects, analyzer.labelEncoder.classes_)
        #         plt.title('Prediction results in the %d different frequency bands'%n_bands, size=14)
            # Predicted probabilities
            ax = plt.subplot(gs[3+i*n_bands+1+1*i%2])
            s1 = self.predictedProbas[n_bands-1-i,:,:].astype(np.double)
            mask1 = np.isfinite(s1)
            mask1 = mask1[:,0]  # /!\ safe in this case: index 0 is None => all are None
        #     # lineObjects = ax.plot(x[mask1],self.predictedProbas[n_bands-1-i,mask1],'.')
            ax.plot(x[mask1],self.predictedProbas[n_bands-1-i,mask1],'.') # Est-ce-qu'on peut mettre un cmap ici ou pas ?
            colormap = plt.cm.Set1 #nipy_spectral, Set1,Paired
            colors = [colormap(i) for i in np.linspace(0, 1,len(ax.lines))]
            for i,j in enumerate(ax.lines):
                j.set_color(colors[i])

        #     ax.legend(handles=[line])
        #     # plt.gcf().autofmt_xdate()
        #     fig.autofmt_xdate()
        #     dates_format = matplotlib.dates.DateFormatter('%d/%m/%y %H:%M:%S')
        #     # plt.xlim((self.t_start,self.t_end))
        #     ax.xaxis.set_major_formatter(dates_format)
        #     plt.yticks([0,0.2,0.4,0.6,0.8],size=14)
        #     plt.xticks(fontsize=14)
        #     title = 'Probability and \npredicted class\n' + '(%d-%d Hz)'%(config.analysis['bandwidth']['f_min'][n_bands-1-i],config.analysis['bandwidth']['f_max'][n_bands-1-i])
        #     plt.ylabel(title, size=14)
        #     plt.xlabel('Date', size=14)
        #     plt.yticks(fontsize=14)


        # General things on the figure
        fig.subplots_adjust(hspace=0)
        title = self.path.split('/')[-1].split('.')[0]
        plt.suptitle(title, size=20)
        # fig.autofmt_xdate() # <-- does not work alone, and kills everythink if uncommented
        dates_format = matplotlib.dates.DateFormatter('%d/%m/%y %H:%M:%S')
        plt.xlim((self.t_start,self.t_end))
        ax.xaxis.set_major_formatter(dates_format)
        plt.xticks(fontsize=14, rotation=30)
        #


        # If online displaying needed
        if onlineDisplay:
            plt.show()

        # If saving needed
        if saveDisplay:
            path = config.general['project_root'] + config.application['name'].upper() + '/res/' + config.configuration_number + '/' + config.general['path_to_visuals']
            plt.savefig(path+title+'.png',format='png')
            if self._verbatim > 1:
                print("\tRecording display has been saved")

        plt.clf()
        plt.close(fig)
        return
