![image alt <](CODE/icons/ipgp/logo_WebObs_C110.png) 

WebObs is an integrated web-based system for data monitoring and networks management. Seismological and volcanological observatories have common needs and often common practical problems for multi disciplinary data monitoring applications. In fact, access to integrated data in real-time and estimation of uncertainties are keys for an efficient interpretation, but instruments variety, heterogeneity of data sampling and acquisition systems lead to difficulties that may hinder crisis management. In the Guadeloupe observatory, we have developed in the last 15 years an operational system that attempts to answer the questions in the context of a pluri-instrumental observatory. Based on a single computer server, open source scripts (with few binaries) and a Web interface, the system proposes:
 
- an extended database for networks management, stations and sensors (maps, station file with log history, technical characteristics, meta-data, photos and associated documents);	
- a web-form interfaces for manual data input/editing and export (like geochemical analysis, some of the deformation measurements, ...);
- routine data processing with dedicated automatic scripts for each technique, production of validated data outputs, static graphs on preset moving time intervals, possible e-mail alarms, sensors and station status based on data validity;	
- in the special case of seismology, a multichannel continuous stripchart associated with EarthWorm/SeisComP acquisition chain, event classification database, automatic shakemap reports, regional catalog with associated hypocenter maps. 	


## Present state and availability

WebObs is presently fully functional and used in a dozen observatories, but the documentation is mostly incomplete. We hope to shortly finish the main user's manual. If you are in a hurry, please contact the project coordinator and we will be happy to help you to install it. 	

## Installation / upgrading	

 To run WebObs you need to install the package which contains a setup script that will set all configuration files. Installing WebObs is not a classical compilation from sources with 'make'. A part of it requires the free Matlab runtime library, because package contains some compiled binaries.	

 Download the latest package file and runtime at [WebObs page](http://www.ipgp.fr/~beaudu/webobs.html).	


### A) Installing WebObs \<version\> from its WebObs-\<version\>.tgz	

You create/choose your WebObs directory within which you will execute the setup process. We suggest /opt/webobs. This directory will contain both	
WebObs code AND WebObs data, and will be the DocumentRoot of the WebObs Apache's Virtual Host.	

setup will prompt you for a Linux WebObs userid (aka WebObs Owner) that it will create. The WebObs userid's group will also be added to Apache's user. See the WebObs user manual if you need to create your own WebObs owner. 	

The system-wide /etc/webobs.d symbolic link will identify your WebObs 'active' (production) installation.	

WebObs comes with pre-defined configuration files and pre-defined data objects as a starting point and for demonstration purposes.	

#### Prerequisities	

Graph processes need Matlab compiler runtime 2011b. Download the installer adapted to your architecture in the WebObs directory, the setup will install it during the C) procedure. Or, place it in any local directory then run:	
 
```sh
unzip MCR_<version>_installer.zip	
sudo ./install -mode silent	
```	

A number of programs and Perl modules are needed to run webobs. During the C) installation procedure, setup will list the missing dependencies that must be installed. Under Debian/Ubuntu, you might install them using the following packages:	

```sh
sudo apt-get install apache2 apache2-utils sqlite3 imagemagick mutt xvfb \
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

and update the ETOPO parameters in the `/etc/webobs.d/WEBOBS.rc` file with the lines:

```	
ETOPO_NAME|etopo1_bed_g_i2	
ETOPO_COPYRIGHT|DEM: ETOPO1 NGDC/NOOA
```	

## Authors	

### Project coordination	
* **François Beauducel** - *Project designer and supervisor* - [beaudu](https://github.com/beaudu) - beauducel@ipgp.fr

### Contributors	

* **Didier Lafon**
* **Xavier Béguin** - [XavierBeguin](https://github.com/XavierBeguin) - beguin@ipgp.fr
* **Patrice Boissier** - [PBoissier](https://github.com/PBoissier) - boissier@ipgp.fr	
* **Alexis Bosson** - bosson@ipgp.fr	
* **Didier Mallarino** - didier.mallarino@osupytheas.fr
* **Jean-Marie Saurel** - [ovsm-dev](https://github.com/ovsm-dev) - [jmsaurel](https://github.com/jmsaurel) - saurel@ipgp.fr
* **Philippe Kowalski** - [kokolkow](https://github.com/kokolkow) - kowalski@ipgp.fr
* **Valérie Ferrazzini** - [ferrazzini](https://github.com/ferrazzini) - ferraz@ipgp.fr
* **Christophe Brunet** - [BrunetChristophe](https://github.com/BrunetChristophe/webobs) - brunet@ipgp.fr
* **Philippe Catherine** - [CPS97410](https://github.com/CPS97410) - caterine@ipgp.fr

See also the list of active [contributors](https://github.com/IPGP/webobs/contributors).	

## Citation	

If you use are using WebObs please kindly cite the following paper in your publications:

* Beauducel F., D. Lafon, X. Béguin, J.-M. Saurel, A. Bosson, D. Mallarino, P. Boissier, C. Brunet, A. Lemarchand, C. Anténor-Habazac, A. Nercessian, A. A. Fahmi (2020), WebObs: The volcano observatories missing link between research and real-time monitoring, *Frontiers in Earth Sciences*, [doi:10.3389/feart.2020.00048](https://doi.org/10.3389/feart.2020.00048).

## Copyright	

WebObs - 2000-2020 - Institut de Physique du Globe Paris

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program.  If not, see <http://www.gnu.org/licenses/>.	

