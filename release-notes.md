# WEBOBS RELEASE NOTES

## Important note
This document contains install/upgrade summary and specific instructions for users and administrators.

The lastest release has many improvements, new features and bug fixes.
**Upgrade is recommended for all WebObs administrators**.

Sections with `!!` prefix must be carefully read in case of upgrade. It usually means that the upgrade could change some behavior from previous release installations.


## v2.1.2 (April, 2019)

### Node's events

New form tool to search/display/edit information in the node's events.
The tool link appears as a small magnifying glass icon in the upper
menu of `listGRIDS.pl` page.
	
Configuration includes following new keys in `NODES.rc`:

```
EVENT_SEARCH_CATEGORY_LIST|grid,alias,feature,author,remote,startdate,title,comment,notebook,outcome
EVENT_SEARCH_MAXDISPLAY_LIST|15,50,75,100
EVENT_SEARCH_DEFAULT|alias
EVENT_SEARCH_DEFAULT2|comment
```
where

- `EVENT_SEARCH_CATEGORY_LIST` is a list of preset categories to search in,
- `EVENT_SEARCH_MAXDISPLAY_LIST` sets the list of maximum events per page,
- `EVENT_SEARCH_DEFAULT` and `EVENT_SEARCH_DEFAULT2` are the default category
for first and second search criteria, respectively.

Result table includes links to edit event (if the user has the correct
rights to the associated grid), to display the grid or the node's page.
	

### All procs

1. PROC page now offers a link to edit events file(s) if defined in configuration. If you experience error like *permission denied* you might have to change the file rights for Apache user.

2. Fix a bug making any proc crashes when there was only 1 single data
sample in a timescale.

3. NODE alias that contains an undercore character is now written 
normally in the graphs title or label (no TeX interpretation as 
subscribe position for the next character). TeX formatting is still 
possible in the graph title, any channel, NODE or PROC names. To display an underscore character in these strings, you must escape it (`\_`).


### Sefran/MC

Dumping data bulletin and opening miniseed files now open a new empty
window or tab in the browser.

In the MC table, a new *View* icon indicates now that user can only view an event and not modifying it. Only editable events show the *Edit* icon.

`!!`	Dump .csv bulletin file now includes one additionnal column with event 
	ID as `"yyyy-mm#id"` in the last column.

`!!`	Users with *Edit-level* authorization are now able to edit any event 
	of the reserved type **AUTO**. They are still NOT allowed to modify other
	types of event, excepted if they own the event itself.

### New superproc mc3stats

This new alpha-version superproc reads seismic catologs from Main Courante and plot some elaborated statistics. The PROC must be associated to a catalog NODE with FID as MC3_NAME. Undocumented yet.

### Superproc gnss

1. New GNSS data format `gipsyx` to read outputs from GipsyX 3rd party
software (see also next section).

2. `!!`	New key to select the misfit L-norm:

	```
MODELLING_MISFITNORM|L1
```
which is L1-norm by default. To preserve the previous L2-norm in active
proc, this must be changed to `L2`.

3. `!!`	New key to limit numerical effets:

	```
MODELLING_MINERROR_PERCENT|1
```
which set a minimum relative error of 1% (default) for each data before
computing the inverse problem. This is especially useful when there is 
a large number of stations (more than 10) and/or for long period of time
(more than 1 year). To get the exact previous behavior, this must be changed to `0`.
	
4. Some fixes and improved modelling graphic outputs.


### GNSS GipsyX scripts

New bash shell script and configuration file `gnss_run_gipsyx ` that uses
3rd party programs JPL/GipsyX and Unavco/teqc to process GNSS rawdata 
and to produce PPP solutions in readable files architecture and names 
for the new WebObs `gipsyx` data format and superproc gnss.


## v2.1.1 (January, 2019)

### Superproc gnss

1. `!!` New default color scheme for modelling plots

	```
MODELLING_COLORREF|volpdf
```
combining the source volume sign and probability using a mirror shading
of splitted colormap, for example with default jet colormap, it splits
into cold and warm colors (both increasing probability):

	- deflation is white-green-violet-blue-dark blue
	- inflation is white-yellow-orange-red-dark red
	
	As reminder, the previous default pdf mode uses full colormap from low
to high probability, no volume indication excepted for best model. To reuse the former color scale set the new variable to `pdf`.

2. modelling data error
To avoid numerical problems in modelling, there is now a minimum error
on absolute displacements with a new key:

	```
MODELLING_MINERROR_MM|5
```

### Sefran/MC

1. Fix an issue with mseedreq.pl (miniSEED file request) with data source
new format configuration in `SEFRAN3.conf` (DATASOURCE).

2. For MC display and catalogue dump, signal amplitude filter now can use
`=` (equality, default and former behavior), `≤` (less or equal to) or `≥` 
(greater or equal to) relative to one of the values set in 
`MC3_Amplitudes.conf`.

3. For web-service MC3 dump function `/cgi-bin/mseedreq.pl`, it is possible to add a new argument `&tsnew=` to request only events that have been modified after 
a specific timestamp. Full format is `yyyymmddTHHMMSSzzzz` but can be
truncated anywhere from the right. This function will work only for 
events that have been edited after this release update.

	`!!`	Note this functionality uses a new MC data format, mostly backward-
compatible: there is no additional column, but column of UID operator 
is now UID/timestamp when the event is edited. This is totally
transparent for sefran3 and MC user interfaces, but if you have third 
party tools that reads directly the MC files, you might have to adapt
them.

	`!!`	Dump `.csv` bulletin file now includes two additionnal columns:

	- Amplitude (inserted after Duration)
	- Timestamp (inserted after Operator)


###Superformat quakes

Solves a problem with `scevtlog-xml` format when some data don't have 
preferred magnitude. This affects all quake-compatible superprocs, in
particular hypomap and tremblemaps.
	
	
###Setup

Multiple fixes and improvements in installation.


###user registration

Fix register security issues and add possibility to change password.


## v2.1.0 (December, 2018)

###Sefran3

1. New filtering possibility for individual channels, lowpass, highpass
or bandpass. See `SETUP/CONF/SEFRAN3_Channels.conf` for syntax.

2. New key in SEFRAN3.conf file:

	```
FILTER_EXTRA_SECONDS|0
```	
fixes the number of added seconds of signal before the minute beginning
to avoid filter border effects.

3. Statistic data computed on last minute signals are now integrated in 
the image metadata itself. Temporary external file defined by the key
in SEFRAN3.conf:

	```
CHANNEL_STAT|sefran_chan.dat
```
is now obsolete and can be deleted.


### Node's events

New parameters for node's events:

- end date & time of the event;
- selected feature (from the node's feature list);
- sensor/data outcome flag (will become functional in the future
for associated procs);
-  channel (from calibration file if exists, displayed only for 
node associated with a proc, also possibly functional);
- notebook number (optional);
- notebook forward flag (optional).
	
End date and time parameters will appear in the Gazette (if 
`EVENTS_TO_GAZETTE` is activated in `WEBOBS.rc`). Other parameters appear
only in the node's page.

The two optional notebook parameters can be activated by a new `NODES.rc`
key:

```
EVENTNODE_NOTEBOOK|YES
```
Also, new events can have the notify flag checked by default, using 
new `NODES.rc` key:

```
EVENTNODE_NOTIFY_DEFAULT|YES
```


## v2.0.0 (October, 2018)

###Setup upgrade

When upgrading WebObs, the vimdiff of configuration files has been replaced
by a smarter tool: it detects automatically new keys between templates and
existing configuration and proposes to add new keys with comment into each
files and to edit each of them for double-check.
	
These operations can be refused by admin. In any case, the `SETUP.CONF.README`
file will contain the list of all new keys with explicit headers.


###Scheduler

1. **New kill job command**

	Add a new command to kill a running job: in the CODE/cgi-bin/schedulerRuns.pl
	page interface, click on the delete icon on the left of job runs table and 
	confirm. The icon appears only for running jobs.

	Also possible using the command line:
		CODE/shell/scheduler killjob kid=PID

	Note that scheduler will use a simple "kill PID" command. No further check.


2. **Default values for new job**

	When creating a new job, default values will apply for some fields:

	```
         xeq1  $WEBOBS{JOB_MCC} genplot
     interval  3600
   maxsysload  0.8
        valid  N
```

###New users auto-registration

Possibility to activate an auto-registering for new users, in `WEBOBS.rc`:

```
SQL_DB_USERS_AUTOREGISTER|Y
```
If the user login does not already exists, any new registration will 
	automatically:

1. add a new line to /opt/webobs.d/htpasswd apache file,
2. add a new user in the WebObs user database with validity 'N' and 
   without any associated group. UID is made from initials of the 
   full name, if necessary adding suffix number.

The new registered user won't have access to WebObs until the WebObs user
has been validated by an administrator.

`!!`	Note that `/etc/webobs.d/htpasswd` file must be writable by Apache user.
Reminder: to delete a webobs user, the corresponding login in htpasswd 
file must be deleted first. Any valid login in htpasswd without a
corresponding WebObs user will give a direct access with user *Guest*.
	

###All superprocs

1. **New behavior for NODE's FID_x keys**

	`FID_x` keys are now predefined for each data format (see `CODE/etc/rawformats.conf`). The GUI node editor will display and allow edition of all available keys for a
given data format.
	
	User with admin rights still has possibility to define extra `FID_x` key using 
the "Parameters" link in NODE's page ("Proc" table cell), and edit the .cnf
file manually.


2. **Improved 'delimiter-separated-values' (dsv) data format**

	Format `ascii` data format has been renamed in 'dsv' and improved using
an external gawk preprocessor. See readfmtdata_dsv.m.

3. **New Campbell Scientific TOB1 data format**

	New `tob1` format to read binary data files. See `readfmtdata_campbell.m`.


4. **Bug fixes**

	`!!` Bug fix with some 'globkval' format data files.

	`!!` Bug fix in data export files combined with decimation.


5. **SVG export**

	New experimental export of images in SVG format. Set to any proc:

	```
SVGOUTPUT|Y
```

###Superproc GNSS

1. **Bug fixes**

	`!!` Bug fix with export filenames for baselines. Minor bug fix for linewidth
value in baseline (`LINEWIDTHLIST`).

2. **Local referential**

	Possibility to apply a local referential relative to ITRF using a linear
velocity vector E,N,U (mm/yr) as a constant trend substracted to all 
data before any other processing:

	```
VELOCITY_REF|0,0,0
VELOCITY_REF_ORIGIN_DATE|2000-01-01
```
Origin date is necessary to compute absolute positions, but it will not
affect velocities.


3. **Residual trends per node**

	`!!` When using relative mode (`VECTORS_RELATIVE|Y`), the per node graphs will 
show raw positions (blue) together with relative positions (red), i.e., 
corrected from a global velocity trend. The velocity trend (dashed line)
displayed now correspond to the residual trend of the node.


4. **Baselines pairs**

	New baselines configuration available to set any pairs of nodes:

	```
BASELINES_NODEPAIRS|
```
defining a list of reference node and their target nodes, in the format:
`reference1,target1a[,target1b,...];reference2,target2a[,target2b,...]` reference and target list are node's ALIAS coma separated, graphs are 
semicolon separated.

	Former behavior of baselines is still supported if `BASELINES_NODEPAIRS` is not
defined: as a reminder, all possible pairs of nodes are plotted, with optional 
node(s) exclusion list and/or optional node(s) reference list:

	```
BASELINES_EXCLUDED_NODELIST|
BASELINES_REF_NODELIST|
```

5. **Relative vectors (trend)**

	A new option

	```
VECTORS_RELATIVE_HORIZONTAL_ONLY|Y
```	
setting that default is relative for horizontal components only when 
relative mode is active (`VECTORS_RELATIVE|Y`) in auto mode (`VECTORS_VELOCITY_REF` is void). It was the default behavior for previous releases.


### MC3 / Sefran3

1. **Date selection with local time (but only that)**

	Possibility to add a local time zone for date/hour selection (for display 
and statistics) in MC3. But the data and graphs always remain in UTC !
New keys to add in any `MC3.conf`:

	```
SELECT_LOCAL_TZ|-4
DEFAULT_SELECT_LOCAL|N
```

2. **Specific authorization resource**

	Access authorizations to seismic bulletin MC3 and associated Sefran3 are now
managed by the following resource names for users/groups:

	- `MC` remains default for any existing MC3/Sefran3,
	- `MC3_NAME` stands for a specific MC3 with code/name **'MC3_NAME'**.
	
3. **New external catalog visit**

	New key defining the full html link code for external catalog event check
when editing an event in MC3:

	```
VISIT_LINK|<A href="http://www.emsc-csem.org/Earthquake/" target="_blank"><B>EMSC</B></A>
```	
which might replace the former USGS_URL key. Note that USGS catalog must
be accessed by https:// now:

	```
USGS_URL|https://earthquake.usgs.gov/earthquakes/map
```

###Superprocs hypomap and tremblemaps / quake data format

New filter (in addition to event type and status) applying on the 'comment'
field of event which corresponds to MC3 type if the catalog NODE has been
associated to an MC3 buletin (using `FID_MC3`):

```
EVENTCOMMENT_EXCLUDED_REGEXP|AUTOMATIC
```	
The filter is using case-insensitive regular expression pattern. Empty or
unset value won't filter any event.


###Gazette

In order to limit the long list of users (that must includes unvalid users)
when creating a new event, new key in Gazette.rc:

```
ACTIVE_GID|DUTY
```	
will display only users in the +DUTY group.

`!!`	Former behavior is still active: without `ACTIVE_GID` key, only the active
users will be listed.


-----------------------------------------------


