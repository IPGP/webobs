# Automatic classification for seismic events

Welcome to this automatic classification scheme! Please carefully read the following before asking questions :)

This WebObs feature is based on Marielle MALFANTE (Malfante et al., 2018) and Alexis FALCIN (Falcin et al., 2021) research works to classify automatically discrete (sparse) events, with real-time conditions and data requests. That is to say, events are already detected and you want to classify them with real-time data requests.

In our case, we proposed to predict seismic events of the sefran/MC in real-time. There are two different steps: the training phase and the analysis one:
- The training step is to train and save a model using a labelled dataset coming from the main-courante.
- The analyze step is to run the analysis of new seismic events into the sefran in real-time (knowing its starting date and duration).

## How to use the code?

### Prerequisites
- Install Perl modules: `sudo apt-get install libjson-perl jq`
- Install Python 3 (a version greater than or equal to 3.5.3)
- Install pip for Python 3: `sudo apt-get install python3-pip`

### Installation
- (Optional: Create and activate a virtual environment python -m venv VenvName , source pathTo/VenvName/bin/activate)
- Install Python packages as ROOT administrator: move to the Python AAA code (cd ../../ python/AAA) and run `pip install -r requirements.txt`.

### Usage
The training phase is not integrated into WebObs routine jobs, but can be run manually or through the scheduler for example. The analyzing phase is fully integrated in Sefran3 and associated MC3.

## Training phase

### Configuration

#### WEBOBS.rc
The training step needs to make a request for MC3 catalogue through web-service. This might need a user authentication. In the `WEBOBS.rc` file, update the `NETRC_FILE|/home/wo/.netrc` variable to manage your auto-login into the WebObs system. The `.netrc` file should looks like this:
```
machine <webobs _instance>
login <user_login>
password <user_password>
```

#### MC3.conf
Edit the `MC3.conf` and fill the following key|value pairs under "#predict seismic_events (= PSE)":

- `PSE_ROOT_CONF|$WEBOBS{ROOT_CONF}/PSE` root path of the configuration folder for PSE
- `PSE_ROOT_DATA|$WEBOBS{ROOT_DATA}/PSE`  root path of the data folder for PSE
- `PSE_ALGO_FILEPATH|$WEBOBS{ROOT_CODE}/python/AAA/USECASE3_REAL_TIME_SPARSE_CLASSIFICATION_ANALYSE.py` filepath of the analyzer prediction algorithm
- `PSE_CONF_FILENAME|XXXX_general_3_0X.json` filename of the general setting file. Traditionally, setting files are stored in the PSE_ROOT_CONF folder. The next section gives details on the formatting of configuration files.
- `PSE_TMP_FILEPATH|$WEBOBS{PATH_TMP_WEBOBS}/tmppse.mseed` filepath of the temporary file to save seismic data with mseed file extension
- `PSE_TMP_CATALOGUE|$WEBOBS{PATH_TMP_WEBOBS}/tmppse_catalogue.csv` filepath of the temporary catalogue downloaded from the main-courante (without any filtering).

#### MC3_Codes.conf
Edit the event codes configuration file pointed by `EVENT_CODES_CONF` variable and update the PSE column following the event class you want to be learned into your classification.


### Configuration files

All the settings related to a new run/model are indicated in a setting main setting.

It contains information regarding the project paths, the filenames to save, the signals preprocessing, the features used (linked to a dedicated feature configuration file), and the learning algorithms.

Extra information regarding the wanted filtering, the data to analyze and display parameters are indicated in a separate configuration file.

So, for each configuration, 3 configuration files are considered:

- the general setting file, i.e. `XXXX_general_3_XX.json` file.
- the feature setting file, i.e. `features_XX` file.
- the configuration file specific to the wanted analysis, i.e. `XXXX_specific_3_XX.json`

Commented examples for the general and specific setting files are available (but keep in mind that json files do not support comments, so those files are simply there as examples.)


### Run the training
Move into the perl code folder and run `./training.pl date1 date2 s3 conf`:
- `date1` and `date2` are the start date and end date of the learning period. A request is made to download the bulletin .csv file. Dates need to be in the YYYYMMDDHH format,
- `s3` is the sefran3 name (will define the datasource and associated MC3),
- `conf` is the file path of the general setting file.

The execution of the training command may take a while so please be patient. When it is done we advise you to take time to analyse the outputs. In order to help you in tuning the model, a python notebook is under development.  


## Analyze phase

To be able to predict new seismic-events input, you only need to set on the predict seismic-event option (Obviously, analysis cannot be run without a trained model.)
Move to the `MC3.conf` and change the `PREDICT_EVENT_TYPE` value to either:
- `AUTO`: computes the prediction probabilities as soon as you open a new main-courante window annotation or if the probabilities as never been compute,
- `ONCLICK`: computations are made only when you click on a button and then save.

The PSE WebObsfeature is now ready to be used!!!

As it is a new feature to the WebObs feel free to add a comment about the results of the PSE. It can be useful for better tuning the model.

## References
- Malfante M., M. Dalla Mura, J.-P. Métaxian, J. Mars, O. Macedo, et al. (2018). Machine Learning for Volcano-Seismic Signals: Challenges and Perspectives. *IEEE Signal Processing Magazine, Institute of Electrical and Electronics Engineers*, 35(2), 20-30. https://doi.org/10.1109/MSP.2017.2779166
- Falcin A., J.-P. Métaxian, J. Mars, É. Stutzmann, J.-C. Komorowski, R. Moretti, M. Malfante, F. Beauducel, J.-M. Saurel, C. Dessert, A. Burtin, G. Ucciani, J.-B. de Chabalier, A. Lemarchand (2021). A machine-learning approach for automatic classification of volcanic seismicity at La Soufrière Volcano, Guadeloupe, *Journal of Volcanology and Geothermal Research*, 411, 107151. https://doi.org/10.1016/j.jvolgeores.2020.107151.
