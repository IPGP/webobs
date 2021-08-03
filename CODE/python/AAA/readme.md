# Automatic Classification

Welcome to this automatic classification scheme! Please carefully read the following before asking questions :)

This code is based on Marielle MALFANTE (Malfante et al., 2018) and Alexis FALCIN (Falcin et al., 2021) research works to classify automatically discrete (sparse) events, with real time conditions and data requests. That is to say events are already detected and you want to classify them with real time data request.

Automatic classification of continuous signals, stored in recording files (.wav, .sac, .msd, etc) and/or automatic classification of discrete (sparse) events, stored as numpy.array objects. Extensions to this code can be added using the research work of Marielle MALFANTE (https://github.com/malfante/AAA).

## How to run the code?

In your favorite terminal window, start by moving to the python code folder using `cd` command.

Open the usecases .py files and modify the shebang with your local python setup path.
(You can use the following command: `python -c "import sys; print(sys.executable)"`)

Then run one of the following commands:

     ./USECASE3_REAL_TIME_SPARSE_CLASSIFICATION_TRAINING.py root_conf root_data tmp_filepath setting_filename datasource verbatim

     ./USECASE3_REAL_TIME_SPARSE_CLASSIFICATION_ANALYSE.py root_conf root_data tmp_filepath setting_filename datasource year month day hour minut second duration verbatim

Small modifacations into the usecase scripts can be made if you prefer to used a Python playgrounds to experiment.

## Training usecase

Training usercase is to train and save a model.

## Analysis case

Analyze usercase is to run the analysis of a new input events (knowing its starting date and duration as a input parameters).
Obviously, usercase analysis cannot be run without a trained model.

##### Few more detail on the input arguments
- `root_conf` : root path of the configuaration folder.

- `root_data` : root path of the data folder.

- `tmp_filepath` : filepath of the temporary file with mseed format (i.e.'/tmp/tmpfile.mseed').

- `setting_filename`: filename of the general setting file. Traditionnaly, setting file are stored in the `config` folder. The next section gives details on the formatting of configuration files.

- `datasource`: data source protocole. Protocole used to read data from online server

- `verbatim`:
	- 0 - quiet
	- 1 - some information regarding general steps
	- 2 - more detailed information
	- 3 - all details

## Configuration files

All the settings related to a new project or a new run are indicated in a setting main setting.

It contains information regarding the project paths, the filenames to save, the signals preprocessing, the features used (linked to a dedicated feature configuration file), and the learning algorithms.

Extra information regarding the wanted filtering, the data to analyze and display parameters are indicated in a separate configuration file.

So, for each configuration, 3 configuration files are considered:

- the general setting file, i.e. `XXXX_general_3_XX.json` file.
- the feature setting file, i.e. `features_XX` file.
- the configuration file specific to the wanted analysis, i.e. `XXXX_specific_3_XX.json`

Commented examples for the general and specific setting files are available (but keep in mind that json files do not support comments, so those files are simply there as examples.)

## Advanced usage
Depending of your usecase you may need to add some code:
- If you use a python machine learning algorithm not included in the list below you need to add the package library to `config.py` and `analyzer.py`.
Algorithm list: RandomForestClassifier, AdaBoostClassifier, LogisticRegression, DecisionTreeClassifier, KNeighborsClassifier, LinearDiscriminantAnalysis, QuadraticDiscriminantAnalysis, GaussianNB, SVC, MLPClassifier
- If you use a python cross-validator not included in the list below you need to add the package library to `config.py` and `analyzer.py`.
Crosss-validator list: KFold, RepeatedKFold, RepeatedStratifiedKFold, ShuffleSplit, StratifiedKFold, StratifiedShuffleSplit
- If the protocol to access to your data remotely is not arclink, seedlink or fdsnws-dataselect, your need to implement your own data request function into `DataReadingFunctions`.
- If your features functions are not implemented on the code yet, you can add your functions into `FeaturesFunctions.py`.

## More info

- Malfante M., M. Dalla Mura, J.-P. Métaxian, J. Mars, O. Macedo, et al. (2018). Machine Learning for Volcano-Seismic Signals: Challenges and Perspectives. *IEEE Signal Processing Magazine, Institute of Electrical and Electronics Engineers*, 35(2), 20-30. https://doi.org/10.1109/MSP.2017.2779166
- Falcin A., J.-P. Métaxian, J. Mars, É. Stutzmann, J.-C. Komorowski, R. Moretti, M. Malfante, F. Beauducel, J.-M. Saurel, C. Dessert, A. Burtin, G. Ucciani, J.-B. de Chabalier, A. Lemarchand (2021). A machine-learning approach for automatic classification of volcanic seismicity at La Soufrière Volcano, Guadeloupe, *Journal of Volcanology and Geothermal Research*, 411, 107151. https://doi.org/10.1016/j.jvolgeores.2020.107151.

If you still have questions, try running and exploring the code and then fell free to ask!
