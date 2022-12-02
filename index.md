WebObs is an integrated web-based system for data monitoring and networks management. Seismological and volcanological observatories have common needs and often common practical problems for multi disciplinary data monitoring applications. In fact, access to integrated data in real-time and estimation of uncertainties are keys for an efficient interpretation, but instruments variety, heterogeneity of data sampling and acquisition systems lead to difficulties that may hinder crisis management. In the Guadeloupe observatory, we have developed in the last 15 years an operational system that attempts to answer the questions in the context of a pluri-instrumental observatory. Based on a single computer server, open source scripts (with few free binaries) and a Web interface, the system proposes:

- an extended database for networks management, stations and sensors (maps, station file with log history, technical characteristics, meta-data, photos and associated documents);
- a web-form interfaces for manual data input/editing and export (like geochemical analysis, some of the deformation measurements, ...);
routine data processing with dedicated automatic scripts for each technique, production of validated data outputs, static graphs on preset moving time intervals, possible e-mail alarms, sensors and station status based on data validity;
- in the special case of seismology, a multichannel continuous stripchart associated with EarthWorm/SeisComP acquisition chain, event classification database, automatic shakemap reports, regional catalog with associated hypocenter maps.

WebObs is presently fully functional and used in a dozen observatories (see the related [publications](#wopubs)) and was [awarded in 2022](#woaward), but the documentation for end users is still incomplete and there is no tutorial. We hope to shortly finish the main user's manual. If you are in a hurry, please contact the project coordinator and we will be happy to help you to install it. WebObs is fully described in the following paper (please cite this one if you publish something using WebObs):

>Beauducel F., D. Lafon, X. Béguin, J.-M. Saurel, A. Bosson, D. Mallarino, P. Boissier, C. Brunet, A. Lemarchand, C. Anténor-Habazac, A. Nercessian, A. A. Fahmi (2020). <b>WebObs: The volcano observatories missing link between research and real-time monitoring</b>, <i>Frontiers in Earth Sciences</i>, [doi:10.3389/feart.2020.00048](https://doi.org/10.3389/feart.2020.00048).

<a name="latest"></a>
## Download the latest release

- [WebObs-2.5.3.tar.gz](https://github.com/IPGP/webobs/releases/download/v2.5.3/WebObs-2.5.3.tar.gz) (100 Mb) updated September 23, 2022
- [Release notes](https://github.com/IPGP/webobs/blob/v2.5.3/release-notes.md) (see also the [What's new?](#whatsnew) section below)
- [User manual](https://github.com/IPGP/webobs/releases/download/v2.5.3/WebObs_Manual.pdf) (in progress)
- And, for a first install:
  - Mandatory (license free): **Matlab runtime** for [Linux 64bit](http://www.ipgp.fr/~beaudu/webobs/MCR_Runtime/MCR_R2011b_glnxa64_installer.zip) (386 Mb) or [Linux 32bit](http://www.ipgp.fr/~beaudu/webobs/MCR_Runtime/MCR_R2011b_glnx86_installer.zip) (389 Mb)
  - Recommanded: **ETOPO1** (see [below](#srtm1) for download and install)
- Previous releases are available [here](https://github.com/IPGP/webobs/releases) and older packages [here](http://www.ipgp.fr/~beaudu/webobs/).

For install and update, please follow instructions below.

**IMPORTANT:** when upgrading from a previous version, please read carefully the information at the end of the procedure: some updates may require changes in your configuration files.


Source code, comments and issues are available at the project repository [github.com/IPGP/webobs](https://github.com/IPGP/webobs).


<a name="install"></a>
## Installation / upgrading

To run WebObs you need to install the package which contains a setup script that will set all configuration files. Installing WebObs is not a classical compilation from sources with 'make'. A part of it requires the free Matlab runtime library because package contains some compiled binaries for optimization purpose.

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
sudo apt install apache2 apache2-utils sqlite3 imagemagick pngquant qrencode mutt xvfb \
   curl gawk graphviz net-tools libdatetime-perl libdatetime-format-strptime-perl libdate-calc-perl \
   libcgi-session-perl libdbd-sqlite3-perl libgraphviz-perl libimage-info-perl \
   libtext-multimarkdown-perl libswitch-perl libintl-perl libncurses5
```

Compiled binaries are using some ISO-8859-1 encoding characters... to get correct display you might install some additional locale. Uncomment `fr_FR ISO-8859-1` and `en_US ISO-8859-1` lines in `/etc/locale.gen`, then:

```sh
sudo locale-gen fr_FR en_US
```

Also you need to activate CGI module for Apache:

```sh
sudo a2enmod cgid
```

Create the target WebObs directory:
```sh
sudo mkdir -p /opt/webobs
```

<a name="update"></a>
### B) Upgrading WebObs \<version\> from its WebObs-\<version\>.tgz

The setup process is also used for upgrading an already installed WebObs.

`setup`, when 'upgrading' will activate new WebObs code AND only report the data/configuration differences that it can detect between your customized installation and what the new version would installed from scratch.

It is recommended to stop any WebObs-related processes before upgrading.

Configuration files will be updaded and displayed/editabled at the end of the upgrade process to help you apply required changes to configuration/data.


### C) Procedure for both A) and B) above

With root privileges, in your target WebObs directory:
1. execute `cd /opt/webobs`
2. execute `tar xf WebObs-<version>.tar.gz`
3. execute `WebObs-<version>/SETUP/setup`
4. (re)start Apache
5. launch the scheduler and postboard

For users of systemd-base GNU/Linux distributions, the `setup` proposes an automatic installation for _scheduler_ and the _postboard_ services. If you accepted it, you can launch both systemd services with the following commands:
```sh
sudo service woscheduler start
sudo service wopostboard start
```

<a name="srtm1"></a>
### D) Improving basemap database (recommanded)

WebObs is distributed with ETOPO5 worldwide topographic data, which is very coarse. For details maps on land, WebObs uses SRTM3 topographic data, automatically downloaded from the internet. To improve offshore parts of maps, you can freely download ETOPO1:

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


<a name="whatsnew"></a>
## What's new and release history

### What's new in the 2.5?
- SEFRAN3/MC3 can use key shortcuts to select the event type and amplitude;
- new functionalities in superproc GNSS (harmonic correction, velocity scale) and GENPLOT (moving averages), node events are plotted in background for pernode graphs (most superprocs);
- external node maps now use OpenStreetMaps with various free tile layers (satellite, terrain, topo, ...);
- neighbour nodes are automatically displayed with dynamic links;
- QR codes available for all grids, output graphs and nodes pages (link to direct URL);
- node-feature-node association editable through node configuration GUI;
- improved node events search tool;
- some fixes and other minor improvements.

### What's new in the 2.4?
- SEFRAN3/MC3 includes a machine learning module for automatic event classification;
- new forms for soil solution and rain water chemical analysis;
- new modelling capabilities (pCDM MODELTIME) in GNSS superproc;
- Sefran3 is now a grid type associated to a domain, with configuration GUI;
- some fixes and other minor improvements.

### What's new in the 2.3?
- nodes have one different calibration file per associated proc;
- new modelling capabilities, and new network sensitivity 3D maps in GNSS superproc;
- new parameters in DSV data superformat;
- improved proc access and maps display in showGRID;
- new CSS classes;
- Sefran3 accepts data flux from Winston server;
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

<a name="woaward"></a>
## Awards
The WebObs system has been awarded by a **"Community" accessit** during the **First Open Science Award Ceremony**, *Paris Open Science European Conference (OSEC)*, February 4-5, 2022. See related articles (mostly in French):
- [Ministère de l'Enseignement Supérieur et de la Recherche](https://www.enseignementsup-recherche.gouv.fr/fr/remise-des-prix-science-ouverte-du-logiciel-libre-de-la-recherche-83576)
- [Institut de Physique du Globe de Paris](https://www.ipgp.fr/fr/logiciel-webobs-recompense-lors-de-premiere-edition-prix-science-ouverte-logiciel-libre-remis-mesri)
- [Université Paris Cité](https://u-paris.fr/le-logiciel-webobs-laureat-de-la-premiere-edition-du-prix-science-ouverte-du-logiciel-libre-de-la-recherche/)
- [Resif/EPOS](https://www.resif.fr/blog/2022/02/22/prix-national-de-la-science-ouverte-le-logiciel-webobs-recompense/) [English version](https://www.resif.fr/en/blog/2022/02/22/national-open-science-award-webobs-software-wins-award/)

## References
<a name="worefs"></a>
### Publications on the WebObs system
1. Beauducel, F. and C. Anténor-Habazac (2002), **Quelques éléments d'une surveillance opérationnelle...**, *Journées des Observatoires Volcanologiques, Institut de Physique du Globe de Paris, 25 janvier 2002*. [PDF](http://www.ipgp.fr/~beaudu/2002_Beauducel_Antenor-Habazac.pdf) (in French)
1. Beauducel, F., Anténor-Habazac, C., & Mallarino, D. (2004). **WEBOVS: Integrated monitoring system interface for volcano observatories**. *IAVCEI General Assembly, Pucon, Chile, November 2004*, poster. [PDF](http://web2013prod.ipgp.fr/~beaudu/download/2004_Beauducel_IAVCEI.pdf)
1. Beauducel, F. (2006). **Operational monitoring of French volcanoes: Recent advances in Guadeloupe**, *Géosciences*, Editions BRGM, n°4, p 64-68, 2006. [Abstract](http://www.ipgp.fr/~beaudu/2006_Beauducel_Geosciences.html)
1. Beauducel, F., A. Bosson, F. Randriamora, C. Anténor-Habazac, A. Lemarchand, J-M Saurel, A. Nercessian, M-P Bouin, J-B de Chabalier, V. Clouard (2010). **Recent advances in the Lesser Antilles observatories - Part 2 - WEBOBS: an integrated web-based system for monitoring and networks management**, *Paper presented at European Geosciences Union General Assembly, Vienna, 2-7 May 2010*. [Abstract](http://www.ipgp.fr/~beaudu/2010_Beauducel_EGU.html)
1. Beauducel F., D. Lafon, X. Béguin, J.-M. Saurel, A. Bosson, D. Mallarino, P. Boissier, C. Brunet, A. Lemarchand, C. Anténor-Habazac, A. Nercessian, A. A. Fahmi (2020), **WebObs: The volcano observatories missing link between research and real-time monitoring**, *Frontiers in Earth Sciences*, [Open Access Full Article](https://doi.org/10.3389/feart.2020.00048)

<a name="wopubs"></a>
### Publications citing or using data from WebObs

#### Multidisciplinary
1. Truong, F. et al. (2009). MAGIS: The information system of IPGP magnetic observatories. *In Proceedings of the XIIIth IAGA Workshop on Geomagnetic Observatory Instruments, Data Acquisition and Processing, June 9-18 2008.* [PDF](http://www.ipgp.jussieu.fr/~chulliat/papers/Truong_etal_2009.pdf)
1.  Cole P. et al. (2011), MVO scientific report for volcanic activity between 1 November 2010 and 30 April 2011, [Open File Report OFR 11-01](http://www.mvo.ms/pub/Open_File_Reports/MVO_OFR_11_02-MVO_Report_to_SAC_16.pdf).
1.  Boissier P. et al. (2014). Acquisition, capitalization, modeling and sharing of volcanic and seismic monitoring data at La Réunion Island. *In EGU General Assembly Conference Abstracts*, p. 7964.
1.  Lemarchand, A. et al. (2014). Significant breakthroughs in monitoring networks of the volcanological and seismological French observatories. *In EGU General Assembly Conference Abstracts* p. 14987.
1.  Villemant B. et al. (2014). The hydrothermal system of La Soufrière of Guadeloupe (Lesser Antilles): 35 years of geochemical monitoring with particular emphasis on halogens tracers, *J. Volcanol. Geotherm. Res.*, [doi:10.1016/j.jvolgeores.2014.08.002](https://doi.org/10.1016/j.jvolgeores.2014.08.002)
1. Peltier  A. et al. (2015). Are Piton de la Fournaise (La Réunion) and Kīlauea (Hawai‘i) Really “Analog Volcanoes”?, *in Hawaiian Volcanoes: From Source to Surface (eds R. Carey, V. Cayol, M. Poland and D. Weis), John Wiley & Sons, Inc, Hoboken, NJ.* [doi:10.1002/9781118872079.ch23](https://doi.org/10.1002/9781118872079.ch23)
1. Boudoire G. et al. (2017), New perspectives on volcano monitoring in a tropical environment: continuous measurements of soil CO2 flux at Piton de la Fournaise (La Réunion Island, France), *Geophys. Res. Lett.*, [doi:10.1002/2017GL074237](https://doi.org/10.1002/2017GL074237).
1. Boudoire G. et al. (2017), Investigating the deepest part of a volcano plumbing system: evidence for an active magma path below the western flank of Piton de la Fournaise (La Réunion Island), *J. Volcanol. Geotherm. Res.*, [doi:10.1016/j.jvolgeores.2017.05.026](https://doi.org/10.1016/j.jvolgeores.2017.05.026)
1. Tulet P. et al. (2017), First results of the Piton de la Fournaise STRAP 2015 experiment: multidisciplinary tracking of a volcanic gas and aerosol plume. *Atmospheric Chemistry and Physics*, [doi:10.5194/acp-17-5355-2017](htpps://doi.org/10.5194/acp-17-5355-2017)
1. Boudoire G. et al. (2018). Extensive CO2 degassing in the upper mantle beneath ocean basaltic volcanoes: first insights from Piton de la Fournaise volcano (La Réunion Island) coupling CO2 He-Ar systematic and petrology of fluid inclusions. *Geochimica et Cosmochimica Acta*, [doi:10.1016/j.gca.2018.06.004](https://doi.org/10.1016/j.gca.2018.06.004)
1. Boudoire G. et al. (2018), Small-scale spatial variability of soil CO2 flux: implication for monitoring strategy, *J. Volcanol. Geotherm. Res.*, [doi:10.1016/j.jvolgeores.2018.10.001](https://doi.org/10.1016/j.jvolgeores.2018.10.001)
1. Dumont, M. et a. (2019) Imagery of internal structure and destabilisation features of active volcano by 3D high resolution airborne electromagnetism, *Sci. Rep.*, [doi:10.1038/s41598-019-54415-4](https://doi.org/10.1038/s41598-019-54415-4)
1.  Tamburello G. et al. (2019). Spatio-temporal relationships between fumarolic activity, hydrothermal fluid circulation and geophysical signals at an arc volcano in degassing unrest: La Soufrière of Guadeloupe (French West Indies). *Geosciences*, [doi:10.3390/geosciences9110480](https://doi.org/10.3390/geosciences9110480)
1. REVOSIMA (2019). Bulletin de L'Activité Sismo-Volcanique à Mayotte. *Technical Report ISSN: 2680-1205, IPGP/BRGM.* Available online at [www.ipgp.fr/revosima]()
1.  Moretti R. et al. (2020). The 2018 unrest phase at La Soufrière of Guadeloupe (French West Indies) andesitic volcano: scrutiny of a failed but prodromal phreatic eruption, *J. Volcanol. Geotherm. Res.*, [doi:10.1016/j.jvolgeores.2020.106769](https://doi.org/10.1016/j.jvolgeores.2020.106769)
1.  Terray L. (2020). From sensor to cloud: An IoT network of radon outdoor probes to monitor active volcanoes. *Sensors*, [doi:10.3390/s20102755](https://doi.org/10.3390/s20102755)
1.  Peltier, A. et al. (2021). Volcano crisis management at Piton de la Fournaise (La Réunion) during the COVID-19 lockdown, *Seismol. Res. Lett.*, [doi:10.1785/0220200212](https://doi.org/10.1785/0220200212)
1.  Feuillet N. et al. (2021). Birth of a large volcanic edifice through lithosphere-scale dyking offshore Mayotte (Indian Ocean), *Nature Geoscience*, [doi:10.1038/s41561-021-00809-x](https://doi.org/10.1038/s41561-021-00809-x)
1.  Trasatti, E. et al. (2021). The Impact of Open Science for Evaluation of Volcanic Hazards. *Frontiers in Earth Science*, [doi:10.3389/feart.2021.659772](https://doi.org/10.3389/feart.2021.659772).
1. Lowenstern, J. B., Wallace, K., Barsotti, S., Sandri, L., Stovall, W., Bernard, B., ... & Garaebiti, E. (2022). Guidelines for volcano-observatory operations during crises: recommendations from the 2019 volcano observatory best practices meeting. *Journal of Applied Volcanology*, 11(1), 1-24. [doi:10.1186/s13617-021-00112-9](https://doi.org/10.1186/s13617-021-00112-9)
1. Chevrel, M. O., Harris, A., Peltier, A., Villeneuve, N., Coppola, D., Gouhier, M., & Drenne, S. (2022). Volcanic crisis management supported by near real-time lava flow hazard assessment at Piton de la Fournaise, La Réunion. *Volcanica*, 5(2), 313-334. [doi:10.30909/vol.05.02.313334](https://doi.org/10.30909/vol.05.02.313334)

#### Seismology
1. Bengoubou-Valérius M. et al. (2008). CDSA: A New Seismological Data Center for the French Lesser Antilles. *Seismol. Res. Lett.*, [doi:10.1785/gssrl.79.1.90](https://doi.org/10.1785/gssrl.79.1.90)
1. Bazin S. et al. (2010). The 2004-2005 les saintes (french west indies) seismic aftershock sequence observed with ocean bottom seismometers. *Tectonophysics*, [doi:10.1016/j.tecto.2010.04.005](https://doi.org/10.1016/j.tecto.2010.04.005)
1.  Saurel J. M. et al. (2010). Recent advances in the Lesser Antilles observatories Part 1: Seismic Data Acquisition Design based on EarthWorm and SeisComP. *In EGU General Assembly Conference Abstracts*, p. 5023.
1.  Beauducel F. et al. (2011). Empirical model for rapid macroseismic intensities prediction in Guadeloupe and Martinique. *C.R. Geoscience*, [doi:10.1016/j.crte.2011.09.004](https://doi.org/10.1016/j.crte.2011.09.004)
1. Roult G. et al. (2012). A new comprehensive classification of the Piton de la Fournaise activity spanning the 1985-2010 period. Search and analysis of short-term precursors from a broad-band seismological station. *J. Volcanol. Geotherm. Res.*, [doi:10.1016/j.jvolgeores.2012.06.012](https://doi.org/10.1016/j.jvolgeores.2012.06.012)
1.  Vorobieva I. et al. (2013). Multiscale mapping of completeness magnitude of earthquake catalogs, *Bull. Seismol. Soc. Am.*, [doi:10.1785/0120120132](https://doi.org/10.1785/0120120132)
1. Roult G. et al. (2014). The "Jerk" Method for Predicting Intrusions and Eruptions of Piton De La Fournaise (La Réunion Island) from the Analysis of the Broadband Seismological RER Station. *In AGU Fall Meeting Abstracts, Vol. 2014, pp. V43A-4844*.
1. Anglade A. et al. (2015). Significant technical advances in broadband seismic stations in the Lesser Antilles, *Adv. Geosci.* [doi:10.5194/adgeo-40-43-2015](https://doi.org/10.5194/adgeo-40-43-2015) 
1.  Lemarchand A. et al. (2015). Validation of seismological data from volcanological and seismological French observatories of the Institut de Physique du Globe de Paris (OVSG, OVSM and OVPF). *In 2nd Scientific and Technical Meetings of Résif*.
1. Ucciani G. (2015). Caractérisation spatiale et temporelle de la sismicité volcanique de la Soufrière de Guadeloupe : relations avec
le système hydrothermal, *Doctorate Thesis, Université Paris Diderot, October 2015*, pp. 235.
1. Savage M. et al. (2015), Seismic anisotropy and its precursory change before eruptions at Piton de la Fournaise volcano, La Réunion, *J. Geophys. Res.*, [doi:10.1002/2014JB011665](https://doi.org/10.1002/2014JB011665)
1. Lengliné, O. et al. (2016), Uncovering the hidden signature of a magmatic recharge at Piton de la Fournaise volcano using small earthquakes, *Geophys. Res. Lett.*, [doi:10.1002/2016GL068383](https://doi.org/10.1002/2016GL068383)
1.  Maggi A. et al. (2017). Implementation of a multi-station approach for automated event classification at Piton de la Fournaise volcano, *Seismol. Res. Lett.*, [doi:10.1785/0220160189](https://doi.org/10.1785/0220160189)
1. Duputel Z. et al. (2019). Constraining spatiotemporal characteristics of magma migration at piton De La Fournaise volcano from pre‐eruptive seismicity. *Geophys. Res. Lett.*, [doi:10.1029/2018GL080895](https://doi.org/10.1029/2018GL080895)
1. Saurel J.M. et al. (2019). High-resolution onboard manual locations of Mayotte seismicity since March 2019, using local land and seafloor stations. *In AGU Fall Meeting Abstracts*, Vol. 2019, pp. V43I-0220.
1. Tan C.T. et al. (2019), Real-time assessment of potential seismic migration within a monitoring network using Red-flag SARA, *J. Volcanol. Geotherm. Res.*, [doi:10.1016/j.jvolgeores.2019.07.004](https://doi.org/10.1016/j.jvolgeores.2019.07.004)
1.  Feron R. et al. (2020). First optical seismometer at the top of La Soufrière volcano, Guadeloupe. *Seismol. Soc. Am., [doi:10.1785/0220200126](https://doi.org/10.1785/0220200126)
1.  Stabile T. A. et al. (2020). The INSIEME seismic network: a research infrastructure for studying induced seismicity in the High Agri Valley (southern Italy). *Earth System Science Data*, [doi:10.5194/essd-12-519-2020](https://doi.org/10.5194/essd-12-519-2020)
1.  Rizal M. H. (2020). Structure of Merapi-Merbabu complex, Central Java, Indonesia, modeled from body wave tomography. Master report, *Master Solid Earth Geophysics, Université de Paris*.
1.  Falcin A. et al. (2021). A machine learning approach for automatic classification of volcanic seismicity at La Soufrière volcano, Guadeloupe, *J. Volcanol. Geotherm. Res.*, [doi;10.1016/j.jvolgeores.2020.107151](https://doi.org/10.1016/j.jvolgeores.2020.107151)
1.  Massin F. et al. (2021). Automatic picking and probabilistic location for earthquake assessment in the Lesser Antilles subduction zone, *CR Géoscience*, [doi:10.5802/crgeos.81](https://doi.org/10.5802/crgeos.81)
1.  Saurel J. M. et al. (2021). Mayotte seismic crisis: building knowledge in near real-time by combining land and ocean-bottom seismometers, first results. *Geophys. J. Int.*, [doi:10.1093/gji/ggab392](https://doi.org/10.1093/gji/ggab392)
1.  Duputel Z. et al. (2021). Seismicity of La Réunion island. *Comptes Rendus Géoscience*, [doi:10.5802/crgeos.77](https://doi.org/10.5802/crgeos.77)
1. Falcin, A. (2022). Détection et classification des signaux sismo-volcaniques de la Soufrière de Guadeloupe par apprentissage supervisé, *Doctorate Thesis, Université Paris Cité, 14 April 2022*.

#### Deformation
1.  Beauducel F. et al. (2014). Real-time source deformation modeling through GNSS permanent stations at Merapi volcano (Indonesia). *In AGU Fall Meeting Abstracts* Vol. 2014, pp. V41B-4800.
1. Beauducel, F., and Carbone, D. (2015). A strategy to explore the topography-driven distortions in the tilt field induced by a spherical pressure source: the case of Mt Etna. *Geophys. J. Int.*, [doi:10.1093/gji/ggv076](https://doi.org/10.1093/gji/ggv076)
1. Peltier A. et al. (2016), Deep fluid transfer evidenced by surface deformation during the 2014-2015 unrest at Piton de la Fournaise volcano, *J. Volcanol. Geotherm. Res.*, [doi:10.1016/j.jvolgeores.2016.04.031](https://doi.org/10.1016/j.jvolgeores.2016.04.031)
1. Kristianto K. et al. (2020). Deformasi Gunung Anak Krakatau Periode Oktober–Desember 2019. *Bulletin of Volcanology and Geological Hazard*, 14(1), 9-17.
1. Pinel V. et al. (2021). Monitoring of Merapi volcano, Indonesia based on Sentinel-1 data. *In EGU General Assembly Conference Abstracts*, pp. EGU21-10392.
1. Syahbana D. et al. (2019). The 2017–19 activity at Mount Agung in Bali (Indonesia): intense unrest, monitoring, crisis response, evacuation, and eruption. *Sci. Rep.*, [doi:10.1038/s41598-019-45295-9](https://doi.org/10.1038/s41598-019-45295-9)
1.  Beauducel F. et al. (2020), Mechanical imaging of a volcano plumbing system from unsupervised GNSS modeling, *Geophys. Res. Lett.*, [doi:10.1029/2020GL089419](https://doi.org/10.1029/2020GL089419)
1. Indrastuti N. et al. (2021). Potential Eruption and Current Activity of Anak Krakatau Volcano, Indonesia. *In IOP Conference Series: Earth and Environmental Science*, Vol. 873, No. 1, p. 012021.
1. Mittal, T., Jordan, J. S., Retailleau, L., Beauducel, F., & Peltier, A. (2022). Mayotte 2018 eruption likely sourced from a magmatic mush. *Earth and Planetary Science Letters*, 590, 117566. [doi:10.1016/j.epsl.2022.117566](https://doi.org/10.1016/j.epsl.2022.117566)
1. Dumont, Q., Cayol, V., Froger, J. L., & Peltier, A. (2022). 22 years of satellite imagery reveal a major destabilization structure at Piton de la Fournaise. *Nature Communications*, 13(1), 1-11. [doi:10.1038/s41467-022-30109-w](https://doi.org/10.1038/s41467-022-30109-w)
1. Cayol, V., Peltier, A., Froger, J. L., & Beauducel, F. (2022). Monitoring Volcano Deformation. *Hazards and Monitoring of Volcanic Activity 2: Seismology, Deformation and Remote Sensing*, 95-165. [doi:10.1002/9781394169610.ch2](https://doi.org/10.1002/9781394169610.ch2)
1. Journeau, C. (2022). Insights into the magma transport beneath active volcanoes from seismic and geodetic networks. *Doctorate thesis, Université Grenoble Alpes, 23 September 2022*, pp. 230.
1. Nikkhoo, M., & Rivalta, E. (2022). Surface deformations and gravity changes caused by pressurized finite ellipsoidal cavities. *Geophys. J. Int., 232(1), 643-655. [doi:10.1093/gji/ggac351](https://doi.org/10.1093/gji/ggac351)
1. Peltier A., S. Saur, V. Ballu, F. Beauducel, P. Briole, J-B. de Chabalier, K. Chanard, D. Dausse, R. Grandin, P. Rouffiac, Y-T. Tranchant, M. Bès de Berc, S. Besançon, P. Boissier, C. Broucke, C. Brunet, K. Canjamalé, E. Carme, P. Catherine, A. Colombain, W. Crawford, R. Daniel, G. Dectot, N. Desfete, C. Doubre, T. Dumouch, C. Griot, M. Grunberg, H. Jund, P. Kowalski, F. Lauret, J. Lebreton, F. Pesqueira, F. Tronel, P. Valty and J. van der Woerd (2022). Ground deformation monitoring of the eruption offshore Mayotte, *Comptes Rendus Géoscience*, in press. [doi:10.5802/crgeos.176](https://doi.org/10.5802/crgeos.176)


#### Critical Zone
1. Gaillardet, J., I. Braud, F. Hankard, S. Anquetin, O. Bour, N. Dorfliger, et al. (2018). OZCAR: The French network of critical zone observatories. *Vadose Zone Journal* 17:180067. [doi:10.2136/vzj2018.04.0067](https://doi.org/10.2136/vzj2018.04.0067)
1. Guerin A., Devauchelle O., Robert V., Kitou T., Dessert C., Quiquerez A., Allemand P. and E. Lajeunesse (2019). Stream‐discharge surges generated by groundwater flow. *Geophysical Research Letters*. https://doi.org/10.1029/2019GL082291
1. Fries D.M., R.H. James, C.Dessert, J. Bouchez, A. Beaumais, C. R. Pearce (2019). The response of Li and Mg isotopes to rain events in a highly-weathered catchment. *Chemical Geology*, 519, 68-82. https://doi.org/10.1016/j.chemgeo.2019.04.023
1. GREC (2020). La ressource en eau et le changement climatique, *Cahier du Groupe Régional d’Experts sur le Climat de la Guadeloupe*. [Article en ligne](http://www.synergile.fr/doc/publication-grec-la-ressource-en-eau-et-le-changement-climatique) (in French)
1. Guoa J., L. Maa, J. Gaillardet, P. B.Sak, Y. Pereyra and J. Engela (2020). Reconciling chemical weathering rates across scales: Application of uranium-series isotope systematics in volcanic weathering clasts from Basse-Terre Island (French Guadeloupe), *EPSL* 530. https://doi.org/10.1016/j.epsl.2019.115874
1. Dessert C, Clergue C, Rousteau A, Crispi O and M.F. Benedetti (2020). Atmospheric contribution to cations cycling in highly weathered catchment, Guadeloupe (Lesser Antilles). *Chemical Geology*, 531. https://doi.org/10.1016/j.chemgeo.2019.119354
1. Gaspard F., S. Opfergelt, C. Dessert, V. Robert, Y. Ameijeir and P. Delmelle (2021). Imprint of chemical weathering and hydrothermalism on the Ge/Si ratio and Si isotopic composition of rivers in a volcanic tropical island, Basse-Terre, Guadeloupe (French West Indies). *Chemical Geology*. https://doi.org/10.1016/j.chemgeo.2021.120283
1. Wong, M. Y., Rathod, S. D., Marino, R., Li, L., Howarth, R. W., Alastuey, A., et al. (2021). Anthropogenic perturbations to the atmospheric molybdenum cycle. Global Biogeochemical Cycles, 35, *e2020GB006787*. https://doi.org/10.1029/2020GB006787
1. Pasquet, S., Marçais, J., Hayes, J. L., Sak, P. B., Ma, L., & Gaillardet, J. (2022). Catchment-scale architecture of the deep critical zone revealed by seismic imaging. *Geophysical Research Letters*, 49, e2022GL098433. https://doi. org/10.1029/2022GL098433
1. Xu‐Yang, Y., Dessert, C., Losno, R. (2022). Atmospheric deposition over the Caribbean region: Sea salt and Saharan dust are sources of essential elements on the island of Guadeloupe. *JGR Atmospheres*. https://doi.org/10.1029/2022JD037175
1. Fernandez N.M., Bouchez J., Derry L.A., Chorover J., Gaillardet J., Giesbrecht I., Fries D., J. L. Druhan (2022). Resiliency of silica export signatures when low order streams are subject to storm events. *Journal of Geophysical Research: Biogeosciences*, 127, e2021JG006660. https://doi.org/10.1029/2021JG006660
