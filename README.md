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

----------------------------------------------------------------------------------------------------
Commit logs for WebObs 2.1.6:

commit c087dd2da4f29912dc62092d28a1bca778c3cfcd

    updates release notes

commit b7d38e6fbdfc0c1c26287766899d103b59838619

    minor improvement in gnss.m baselines

commit 094a97088adf6a3c48a38d579495d7633767b994

    Fix redirection problem in sefran replay mode
    
    The issue happens when using multiple SefraN.
    When the user identifies seismic events in replay mode on the non-default SefraN, he is redirected to the default SefraN after validating the first event.
    Whith this fix, the user will be redirected to the SefraN he came from.
    The fix uses the URL parameters mc3 and s3.

commit 3fe309141d8916e513ab9ba8a2547901c45870a4

    updates release notes

commit 0f43036d93d4eb456a5312af4c940d242efcbb73

    Update release notes with recent changes
    
    Update the notes to mention that the User and notification forms in the
    User Manager now also use checkboxes to control the validity field, just
    like the job form in the Scheduler Manager.

commit b92a2c435d6336f96b7753814dadc40729814fe8

    Improve the use of perl DBI in User Manager
    
    This commit replaces calls to sqlite3 in usersMgr.pl by uses of the perl
    DBI API.
    
    Also introduces reusable functions for handling DBI requests (in the
    future, these functions should be moved to a module and shared with
    other scripts like schedulerMgr.pl).

commit 3e7e469f03d29ed627e5433116801631c5fdb8a4

    Use checkboxes for validity fields
    
    This replaces text fields by checkboxes for the edition of the
    'validity' field in the user and notification forms.
    
    Also fixes the grammar of the page title.

commit 9ddf7af0043c319578af50f7dd6c8a60821812f7

    Improve error messages in User Manager
    
    This makes error messages more explicit in the user manager forms when
    creating a new group or adding a new notification.
    
    Also set an arguably more useful default value for the 'action' field in
    the notification form.

commit 765b897279924c11b8fbc3a69c69ca94bfacf644

    minor changes in smarttext.m and target.m

commit 09a3994bbd0cf37c84eed9bc6a66e39bafa7f92d

    fix an issue in editing node - possible fix to issue #67)

commit 0e07b9514e4fe6bbb4bcfeaa98de6e5fbbe9fe54

    Fix postboard email notifications
    
    This fixes a bug introduced in recent changes in postboard.pl that
    stopped the Postboard from sending notification emails.
    
    This also introduces an additional check to avoid calling the MTA
    program when recipient UIDs all have an empty email address in the
    WebObs user database.

commit 4dabf5a53ae785a13c85b9c2074f4700aa78d34c

    Update release notes for development version
    
    Add the latest enhancements and fixes to the release notes for the
    development version.

commit 949595d29d38f1663958b1dcd1bbe00b894d1bab

    Bug and security fixes and improved HTML interface
    
    These changes fix a bug in the Scheduler Runs web page that prevents
    from displaying the link that allows to kill running jobs. Fix #66.
    
    Also, in the same HTML table, the "Elapsed" column now shows "still
    running" for unfinished jobs instead of a negative time.
    
    This commit however mainly replaces calls to qx() in schedulerMgr.pl and
    schedulerRuns.pl by calls to the DBI interface for running SQLite
    queries and by calls to the function
    WebObs::Scheduler::scheduler_client() to contact the scheduler.
    
    This last change fixes a security issue in both scripts allowing to run
    arbritrary commands on the server to users with the admin level.

commit c01743e5b4058d44b287b7e3702e8bcc14f9860c

    Fix minor javascript error in Scheduler manager
    
    This fixes an error shown on the browser console by scheduler.js in
    schedulerMgr.pl.  The javascript code was not taking into account that
    it is used both in schedulerMgr.pl and schedulerRuns.pl.

commit d6086b54a13e75ed561aa73d81a1e0b48215d8f5

    Update the job definition HTML interface
    
    Replace the text field accepting only 'Y' or 'N' by a checkbox when
    editing a job definition in the scheduler manager web interface.

commit 4885b26c362b25613586a5f7f760c9b67e688fa8

    Improve CLI behaviour for scheduler scripts
    
    Added support for older option names for backward compabitility in
    wsudp.pl.  Also improved argument parsing and print a help screen when
    called without argument.
    
    scheduler.pl now sends a more informative and better formatted reply to
    an unknown command.

commit 08d90d635c060526fc07043bb8947b33ee21108b

    Improve logging of database connection issues
    
    In the Postboard and Scheduler, now also check for warnings when closing
    the database through DBI, and emit a warning message to STDERR using
    warn(). This could make spotting database issues easier.

commit 780f8b41477bf51d7d1487253eafe3a9f56853ed

    setup now installs or updates the systemd services
    
    On systems using systemd, the setup script now proposes to automatically
    install or update the wopostboard.service and woscheduler.service files
    by adapting the provided templates to the system environment (it changes
    the DOCROOT directory and webobs user and group name).
    
    The manual and release notes have be updated to reflect this new
    feature.

commit 454b14733310bd501e3d20b4cfd65405899d6c52

    Update the WebObs manual on scheduler and systemd
    
    The WebObs manual was updated with information on the 'scheduler'
    command and a whole new section on systemd integration for the Postboard
    and the Scheduler.

commit 5b2a63d50fedb0eecc0a18df6485b17315059588

    Improve output of Scheduler status commands
    
    Update the output returned by commands send to the Scheduler to show an
    informative message when the list of jobs are empty in commands 'runq',
    'jobq', and 'qs'.

commit 41d0bb9fee45866244ae1224abd2b33701819950

    Fix systemd service dependency
    
    Add a dependency in the woscheduler service on the wopostboard one so
    the latter is automatically started when the former is. (This line was
    forgotten in the latest update.)

commit 4d69b9139876fb2091837f1a04d9d1f21583602d

    Remove leftover debugging log in postboard

commit 1b9ed05b88f7267b37fc6f37c567fe82204011e0

    Fix postboard error file redirection

commit a05c9b8f4209cf0874e1a551d45beb18eecada75

    Improve scheduler commands outputs
    
    Now sort the list of jobs printed by the scheduler on commands like
    'runq', 'jobq' and 'qs'.
    
    In case of 'runq', both the list of jobs and the provided information
    are sorted to ensure a constant order. The jobs starting date and time
    are also now printed in human readable format to help the administrator.

commit 6989adeccab73ec1aee04711a6b5fe736e918dfd

    Now append to error files of postboard and scheduler
    
    The helper shell scripts 'postboard' and 'scheduler' were truncating the
    Postboard and Scheduler error files on startup, deleting logs from the
    previous run. They now write in append mode and write the date and time
    to these files when starting the background process.

commit 02ad319338984181011ab63fa663748bc7943936

    Fix 'terminate' exit code for 'scheduler' and 'postboard'
    
    Fix the exit code of 'postboard.pl' when receiving a TERM signal.
    
    Also fix exit code detection in shells scripts 'scheduler' and
    'postboard' in the 'terminate' command.

commit 4d28631eb007920c8b3dad2d4e0cf194b9c3d281

    Remove useless execution permission on wolib.bash

commit a0d0170f0e7277c1ce8df78683c11efb187fa563

    Update scheduler man page
    
    Update the man page for the 'scheduler' script to include its new and
    omitted subcommands.
    
    Also update the 'setup' man page to list the '-x/--expert-mode' option.

commit 1137b1d0db7344dc700934bbc50f37f40899255b

    Update the manual with new configuration options
    
    Update the WebObs manual to include the new scheduler configuration
    options LISTEN_ADDR and MERGE_JOB_LOGS.

commit c9a6c5e17c1753e9b3b4009f275549c7537e75f1

    Syntax formatting changes for scheduler and postboard
    
    Further changes in the syntax formatting for scheduler.pl and postboard.pl for
    improved readability (no functional change).

commit 467b24445968be4d0514666bc8cd9b5cd68d19a3

    Fix 2 minors bugs in the postboard
    
    - fix bug in the postboard and `WebObs::Config::notify` that would reject
      action notification requests with an empty argument (the 'message' part of
      the request). Fixes #64.
    
    - also changed the syntax for the definition of `WebObs::Config::notify`
      for enhanced readability (no functional change).
    
    - fix bug in the postboard where the name and address of a user are inverted in
      the `From:` field when providing a `sender-id` in the form of an email

commit 66ba49ae4e3c209f05ce344b6351a91722d8ff48

    New scheduler option to merge jobs stderr and stdout
    
    A new boolean configuration option `MERGE_JOG_LOGS` in the scheduler
    configuration allows to write the job stdout and stderr outputs to a
    same log file (using prefix `.log` instead of `.stdout`/`.stderr`).
    
    If `MERGE_JOG_LOGS` is not `y`, `yes` or `1` or is missing, the old
    behaviour is followed, and outputs will be written to different files.

commit 3ecf90625ba3ef92977bc9b7def0de0d35ee9270

    Non-functional improvements in scheduler and postboard
    
    - removed remaining calls to the sqlite3 shell command through qx(), now
      using the DBI perl interface to connect to the database.
    
    - improved perl syntax readability and homogenisation

commit e67ced40ab65957017c5a4c72ccf716f01ec1ac0

    Remove trailing whitespaces
    
    Remove all remaining trailing whitespaces from the postboard and
    scheduler perl scripts.

commit 9de2fd4798cbcb485845d85bb1601d1273680675

    Improve systemd integration
    
    This commit mainly change the behaviour of 'scheduler.pl' and 'postboard.pl'
    and their helper shell scripts for an improved integration to systemd, along
    with a new feature/fix that allows to bind the Scheduler control interface to
    a specific network interface.
    
    Full description of changes:
    
    - 'scheduler.pl' and 'postboard.pl' no longer check or write the PID file, it
      should be done by the forking process (the shell scripts in our case) to
      ensure a good timing in the availability of the PID file.
    
    - the helper scripts 'scheduler' and 'postboard' no longer refuse to start
      when a PID file exists and the process designated by the PID is not alive.
      For improved crash recovery, they now ignore and remove the PID file and
      normally process the provided command.
    
      This is more in line with systemd behaviour, as the former behaviour could
      confuse the administrator when using systemd: the service would crash at
      first start, but would immediately be successfully restarted by systemd
      (thanks to the Restart= configuration) because systemd automatically removes
      the PID file as part of the 'stop' step of the 'restart' process.
    
      The PID file is now also ignored and removed (with a comment in the logs)
      when the PID file designates a process that does not runs the expected
      script (in case the PID were re-used by another process).
    
    - postboard.pl and scheduler.pl now exit with code 0 (success) when receiving
      the TERM signal so that systemd reports the daemon has exited cleanly.
    
    - for improved reliability, the templates for the systemd services now default
      to directly sending the TERM signal to stop the postboard or the scheduler,
      instead of using a script in ExecStop= that sends the same signal.
    
    - the systemd service woscheduler.service now makes sure wopostboard.service
      is started before it starts itself (to be able to send notifications).
    
    - a new command 'terminate' was added to the 'scheduler' and 'postboard'
      scripts that sends the daemon a TERM signal to exit cleanly with exit code 0
      (without waiting for children processes in the case of the scheduler). This
      is a better alternative to the 'kill' command that should only be used as a
      last resort (or not at all).
    
    - updated the 'scheduler' script to use the newer 'ss' command on systems that
      miss the 'netstat' command (which is not installed by default on latest
      GNU/Linux systems). Fixes #63.
    
    - added scheduler configuration option LISTEN_ADDR to bind the UDP control
      socket to a specific interface (this allows to easily limit access to the
      local machine, as the control protocol does not have any authentication
      system). Fixes #62.
    
    - scheduler.pl now issues a notification when it starts, just like it does
      when it stops. Administrators are thus informed that the scheduler has
      restarted after being stopped.
    
    - the scheduler 'killjob' request now reports when the argument is invalid (it
      should be of the form kid=XXX) or if the job could not be sent the TERM
      signal.
    
    - substituted many system commands run by qx() by native perl functions in
      scheduler.pl and postboard.pl.
    
    - the helper scripts 'scheduler' and 'postboard' now use more explicit
      variables names and factorise verification code using 'case' features to
      improve code maintainability.
    
    - removed some trailing whitespaces.

commit 820de6b0cd9e729da80eacaa4f7449a17018179f

    Make the woconf() bash function reusable
    
    Take the definition of the woconf() bash function out of the 'readconf'
    script and into the new 'wolib.bash' file to be able to reuse it in
    multiple scripts.
    
    Also redefine woconf() to make it easier to read and maintain.

commit 30213a1963b1e1c67e5bd456958370fcae50f0fe

    Complete release notes fror v2.1.5b
    
    Complete the release notes with additional enhancements and bug fixes
    left behind for version 2.1.5b.

----------------------------------------------------------------------------------------------------
