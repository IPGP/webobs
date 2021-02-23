WebObs is an integrated web-based system for data monitoring and networks management. Seismological and volcanological observatories have common needs and often common practical problems for multi disciplinary data monitoring applications. In fact, access to integrated data in real-time and estimation of uncertainties are keys for an efficient interpretation, but instruments variety, heterogeneity of data sampling and acquisition systems lead to difficulties that may hinder crisis management. In the Guadeloupe observatory, we have developed in the last 15 years an operational system that attempts to answer the questions in the context of a pluri-instrumental observatory. Based on a single computer server, open source scripts (with few free binaries) and a Web interface, the system proposes:

- an extended database for networks management, stations and sensors (maps, station file with log history, technical characteristics, meta-data, photos and associated documents);
- a web-form interfaces for manual data input/editing and export (like geochemical analysis, some of the deformation measurements, ...);
routine data processing with dedicated automatic scripts for each technique, production of validated data outputs, static graphs on preset moving time intervals, possible e-mail alarms, sensors and station status based on data validity;
- in the special case of seismology, a multichannel continuous stripchart associated with EarthWorm/SeisComP acquisition chain, event classification database, automatic shakemap reports, regional catalog with associated hypocenter maps.

WebObs is presently fully functional and used in a dozen observatories, but the documentation is mostly incomplete. We hope to shortly finish the main user's manual. If you are in a hurry, please contact the project coordinator and we will be happy to help you to install it. WebObs is fully described in the following paper (please cite this one if you publish something using WebObs):

>Beauducel F., D. Lafon, X. Béguin, J.-M. Saurel, A. Bosson, D. Mallarino, P. Boissier, C. Brunet, A. Lemarchand, C. Anténor-Habazac, A. Nercessian, A. A. Fahmi (2020). <b>WebObs: The volcano observatories missing link between research and real-time monitoring</b>, <i>Frontiers in Earth Sciences</i>, [doi:10.3389/feart.2020.00048](https://doi.org/10.3389/feart.2020.00048).

**IMPORTANT:** when upgrading from a previous version, please read carefully the information at the end of the procedure: some updates may require changes in your configuration files.

## Download the latest release

- [WebObs-2.3.2.tar.gz](https://github.com/IPGP/webobs/releases/download/v2.3.2/WebObs-2.3.2.tar.gz) (58 Mb) updated February 23, 2021
- [Release notes](https://github.com/IPGP/webobs/blob/v2.3.2/release-notes.md)
- [User manual](https://github.com/IPGP/webobs/releases/download/v2.3.0/WebObs_Manual.pdf) (in progress)
- And, for a first install:
  - Mandatory (free): **Matlab runtime** for [Linux 64bit](http://www.ipgp.fr/~beaudu/webobs/MCR_Runtime/MCR_R2011b_glnxa64_installer.zip) (386 Mb) or [Linux 32bit](http://www.ipgp.fr/~beaudu/webobs/MCR_Runtime/MCR_R2011b_glnx86_installer.zip) (389 Mb)
  - Recommanded: **ETOPO1** (see below for download and install)
- Previous releases are available [here](https://github.com/IPGP/webobs/releases) and older packages [here](http://www.ipgp.fr/~beaudu/webobs/).

For install and update, please follow instructions below.

Source code, comments and issues are available at the project repository [github.com/IPGP/webobs](https://github.com/IPGP/webobs).


## Installation / upgrading

To run WebObs you need to install the package which contains a setup script that will set all configuration files. Installing WebObs is not a classical compilation from sources with 'make'. A part of it requires the free Matlab runtime library because package contains some compiled binaries.

### A) Installing WebObs \<version\> from its WebObs-\<version\>.tgz

You create/choose your WebObs directory within which you will execute the setup process. We suggest `/opt/webobs` (default). This directory will contain both
WebObs code and WebObs data, and will be the DocumentRoot of the WebObs Apache's Virtual Host.

setup will prompt you for a Linux WebObs userid (aka WebObs Owner) that it will create. The WebObs userid's group will also be added to Apache's user. See the WebObs user manual if you need to create your own WebObs owner. 	

The system-wide /etc/webobs.d symbolic link will identify your WebObs 'active' (production) installation.

WebObs comes with pre-defined configuration files and pre-defined data objects as a starting point and for demonstration purposes.

#### Prerequisities

Graph processes need Matlab compiler runtime 2011b (available above). Download the installer adapted to your architecture in the WebObs directory, the setup will install it during the C) procedure. Or, place it in any local directory then run:

```sh
unzip MCR_<version>_installer.zip
sudo ./install -mode silent
```

A number of programs and Perl modules are needed to run webobs. During the C) installation procedure, setup will list the missing dependencies that must be installed. Under Debian/Ubuntu, you might install them using the following packages:

```sh
sudo apt-get install apache2 apache2-utils sqlite3 imagemagick pngquant mutt xvfb \
   curl gawk graphviz net-tools libdatetime-perl libdate-calc-perl \
   libcgi-session-perl libdbd-sqlite3-perl libgraphviz-perl libimage-info-perl \
   libtext-multimarkdown-perl libswitch-perl libintl-perl libncurses5
```

Compiled binaries are using some ISO-8859-1 encoding characters... to get correct display you might install some additional locale. Uncomment `FR_FR ISO-8859-1` and `en_US ISO-8859-1` lines in `/etc/locale.gen`, then:

```sh
sudo locale-gen fr_FR en_US
```

Also you need to activate CGI module for Apache:

```sh
sudo a2enmod cgid
```

### B) Upgrading WebObs \<version\> from its WebObs-\<version\>.tgz

The setup process is also used for upgrading an already installed WebObs.

`setup`, when 'upgrading' will activate new WebObs code AND only report the data/configuration differences that it can detect between your customized installation and what the new version would installed from scratch.

It is recommended to stop any WebObs-related processes before upgrading.

Configuration files will be updaded and displayed/editabled at the end of the upgrade process to help you apply required changes to configuration/data.


### C) Procedure (for both A) and B) above)

With root privileges, in your target WebObs directory:

1. execute  `tar xf WebObs-<version>.tar.gz`
2. execute  `WebObs-<version>/SETUP/setup`
3. (re)start Apache
4. launch the scheduler and postboard

For users of systemd-base GNU/Linux distributions, template service definitions for the _scheduler_ and the _postboard_ are available in the `/opt/webobs/WebObs-<version>/SETUP/systemd/` directory.
You can copy these files (as root) to `/etc/systemd/system/` and adapt the user name and group of the Webobs Owner (defaults to `webobs`) to automatically start these services at system boot and restart them if they crash or are killed.

Here are the steps to copy, adapt, and run these systemd services:
```sh
# Copy the files
sudo cp /opt/webobs/WebObs-<version>/SETUP/systemd/wo* /etc/systemd/system/
# Adapt the User= and Group= directoves in the files
sudo nano /etc/systemd/system/woscheduler.service
sudo nano /etc/systemd/system/woscheduler.service
# Enable the services to have them start at boot
sudo systemctl enable woscheduler.service
sudo systemctl enable wopostboard.service
# Start the services to run them immediately
sudo systemctl start woscheduler.service
sudo systemctl start wopostboard.service
```

### D) Improving basemap database (optional)

WebObs is distributed with ETOPO5 worldwide topographic data, and will automatically download SRTM data for detailed maps. To improve large scale maps resolution, you can download ETOPO1:

```sh
curl https://www.ngdc.noaa.gov/mgg/global/relief/ETOPO1/data/bedrock/grid_registered/binary/etopo1_bed_g_i2.zip -o /tmp/etopo.zip
unzip -d /etc/webobs.d/../DATA/DEM/ETOPO /tmp/etopo.zip
```

If the link is broken you might download a copy [here](http://www.ipgp.fr/~beaudu/webobs/etopo1.tgz) (308 Mb) and untar into the WebObs root directory:
```sh
tar xf etopo1.tgz
```

then update the ETOPO parameters in the `/etc/webobs.d/WEBOBS.rc` file with the lines:

```
ETOPO_NAME|etopo1_bed_g_i2
ETOPO_COPYRIGHT|DEM: ETOPO1 NGDC/NOOA
```


## What's new?

### What's new in the 2.3?
- nodes have one different calibration file per associated proc;
- new modelling capabilities, and new network sensitivity 3D maps in GNSS superproc;
- new parameters in DSV data superformat;
- improved proc access and maps display in showGRID;
- new CSS classes,
- some fixes and other minor improvements.

### What's new in the 2.2?
- Sefran3 has a continuous multichannel spectrogram, and compressed PNG images (by 70%);
- new default colormaps (ryb, spectral) for all procs;
- security update, improvements and fixes in all existing superprocs.

### What's new in the 2.1?
- GNSS superproc has new features (improved graphic and modelling capabilities);
- Sefran3 has now signal filtering possibility (lowpass, highpass, bandpass);
- additional parameters for node's events (link to feature or channel, sensor/data outcome, ...);
- new search tool for node's events;
- new superproc mc3stats to make statistics on seismic events;
- all background maps can merge SRTM and ETOPO;
- domains are editable through GUI;
- security update, improvements and fixes in all existing superprocs.

### What's new in the 2.0?
- source code is now on github!
- smarter setup to automatically update configuration files;
- auto-registration for new users;
- scheduler kill job command;
- improvements and fixes in all existing superprocs.

### What's new in the beta-1.8?
- a security fix in woc;
- new data format EarthWorm Winston Wave Server;
- new superproc "RSAM" plotting timeseries and source location maps;
- new superproc "SARA" plotting seismic amplitude ratio analysis;
- channel selection in each NODE for associated PROCS;
- new timescale with a reference date;
- PROCS graph outputs have a new default page "overview" with thumbnails;
- events in time series background have now a pop-up window with event name;
- improvements and fixes in all existing superprocs.

### What's new in the beta-1.7 ?
- a major update of Hebdo: the Gazette!
- superproc "GENPLOT" improved with a lot of new parameters;
- new superproc "HYPOMAP" plotting earthquake maps from different data sources (HYPO71 catalog file, FDNS WebService, QuakeML events tree, ...);
- new superproc "TREMBLEMAPS" producing elaborated earthquake bulletins for felt events;
- new superproc "EXTENSO" plotting timeseries and maps from extensometer manual data (FORM);
- new superproc "NAQSSOHPLOT" plotting timeseries of NAQS metadata stations;
- new superproc "TILT" plotting timeseries, vectors and modelling tiltmeter data;
- new superproc "HELICORDER" plotting nice helicorders from seismic data;
- plots lines of transmission between NODES on location maps (GRID and NODE);
- possibility to add supplementary maps with user-defined area limits (GRID);
- export links of NODE's list in text (TXT), Excel-compatible (CSV) or Google-Earth (KML) formats;
- define a list of PROC's parameter keys that will be editable in the request data form;
- upload/associate photos to a NODE event or sub-event;
- multiple photos/files upload to a NODE;
- quick access link to previous/next photo associated to a NODE;
- photos associated to a NODE are now sorted in chronological order (timestamp from EXIF data);
- improvements and fixes to superprocs SEFRAN3, GENPLOT, GNSS, JERK, METEO.

## References
- Beauducel, F. and C. Anténor-Habazac (2002), **Quelques éléments d'une surveillance opérationnelle...**, Journées des Observatoires Volcanologiques, Institut de Physique du Globe de Paris, 25 janvier 2002. [Full presentation](http://www.ipgp.fr/~beaudu/2002_Beauducel_Antenor-Habazac.pdf) (in French)
- Beauducel, F. (2006). **Operational monitoring of French volcanoes: Recent advances in Guadeloupe**, Géosciences, Editions BRGM, n°4, p 64-68, 2006. [Abstract](http://www.ipgp.fr/~beaudu/2006_Beauducel_Geosciences.html).
- Beauducel, F., A. Bosson, F. Randriamora, C. Anténor-Habazac, A. Lemarchand, J-M Saurel, A. Nercessian, M-P Bouin, J-B de Chabalier, V. Clouard (2010). **Recent advances in the Lesser Antilles observatories - Part 2 - WEBOBS: an integrated web-based system for monitoring and networks management**, Paper presented at European Geosciences Union General Assembly, Vienna, 2-7 May 2010. [Abstract](http://www.ipgp.fr/~beaudu/2010_Beauducel_EGU.html).
- Beauducel F., D. Lafon, X. Béguin, J.-M. Saurel, A. Bosson, D. Mallarino, P. Boissier, C. Brunet, A. Lemarchand, C. Anténor-Habazac, A. Nercessian, A. A. Fahmi (2020), **WebObs: The volcano observatories missing link between research and real-time monitoring**, Frontiers in Earth Sciences, DOI: 10.3389/feart.2020.00048. [Open Access Full Article](https://doi.org/10.3389/feart.2020.00048).
- Beauducel F., A. Peltier, A. Villié, W. Suryanto (2020), **Mechanical imaging of a volcano plumbing system from unsupervised GNSS modeling**, Geophysical Research Letters, [Open Access Full Article](https://doi.org/10.1029/2020GL089419).
