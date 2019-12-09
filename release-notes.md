# WEBOBS RELEASE NOTES

## Important note
This document contains install/upgrade summary and specific instructions for users and administrators.

The lastest release has many improvements, new features and bug fixes.
**Upgrade is recommended for all WebObs administrators**. For known issues, please take a look to [github.com/IPGP/webobs/issues](https://github.com/IPGP/webobs/issues) and do not hesitate to submit any problem with this release.

Sections with `!!` prefix must be carefully read in case of upgrade. It usually means that the upgrade could change some behavior from previous release installations.

## v2.1.4 (December 2019)

### Superproc GNSS
1. New summary graph `MOTION` that can be added to `SUMMARYLIST` showing the displacement particles in a 4-D plot. New variables are:

	```
MOTION_EXCLUDED_NODELIST|
MOTION_MAFILTER|10
MOTION_SCALE_MM|0
MOTION_MIN_SIZE_KM|10
MOTION_COLORMAP|jet(256)
MOTION_DEM_OPT|'colormap',.5*ones(64,3),'watermark',2,'interp'
MOTION_TITLE|{\fontsize{14}{\bf${NAME} - Motion} ($timescale)}
MOTION_TARGET_INCLUDED|Y
```

	`MAFILTER` is a moving-average filter with default 10 samples.
	
	`MOTION_SCALE_MM` can be used to fix the displacement scale corresponding to 30% of the map width (default `0` is automatic).

2. The target (defined by `GNSS_TARGET_LATLON` coordinates) is systematically included in the summary graphs `MODELLING` and `MODELTIME`. It is possible to add it into `VECTORS` and `MOTION` summary graphs with new variables:

	```
	VECTORS_TARGET_INCLUDED|Y
	MOTION_TARGET_INCLUDED|Y
```

3. The graphs per node can include a principal component analysis subplot by setting a negative value for key:

	`PERNODE_TIMEZOOM|-1`
	
	with some options:
	
	```
	PERNODE_PCA_COLOR|0.3,0.6,0
	PERNODE_PCA_MAFILTER|10
```


## v2.1.3f (September, 2019)

### `!!`Security update
This release introduces important improvements in CGI security, in particular register.pl which is not protected by password, but also other scripts now checking input parameters to avoid irregular/unwanted actions.

### Locastat
NODE's location maps now include an altitude value from DEM interpolation, written in the map's comment that may be compared to NODE's altitude given in the configuration.

### Sefran/MC
Sub-menu of seismic bulletin MC3 page now have link(s) to any Sefran3 associated to the displayed MC3. Formerly, it was only a link to the default Sefran3.

Fixed an issue when event seconds are out of range (<0 or >=60).

In the Sefran hourly thumbnails page, added a new checkbox to display/hide trash events, available for Edit/Admin level users only.

The SEFRAN3 configuration key `PATH_TMP` (in `SEFRAN3.conf`) is now obsolete. Each sefran will use temporary path defined as `$PATH_TMP_WEBOBS/sefran3/SEFRAN3_NAME` where `$PATH_TMP_WEBOBS` is general temporary path defined in `WEBOBS.rc` and `SEFRAN3_NAME` is the unique name of the Sefran.

`!!` Export "Events bulletin" CSV file now have the following colums:

```
#YYYYmmdd HHMMSS.ss;Nb(#);Duration;Amplitude;Magnitude;Longitude;Latitude;Depth;Type;File;LocMode;LocType;Projection;Operator;Timestamp;ID
```

The former **Valid** column (0 = automatic, 1 = manual) has been replaced by columns:

* **LocMode:** concatenating `manual` or `automatic` with optional `(confirmed)` information from SC3,
* **LocType:** located event type (like `earthquake` or `not locatable` from SC3).

### Superproc gnss
1. Improvements of MODELTIME summary graph:
	- source volume variation is now expressed as a flux rate in m^3/s
	- additional map with profiles show time evolution of the best sources in space for any subset of time periods
	- source models are not computed if there is no data for the most recent time of integration period

2. Improvement of VECTORS summary graph: a subplot shows vector amplitude vs. distance from target (if defined).
 
3. Improvement of MODELLING summary graph:
	- depth and volume variation are displayed as best value +/- uncertainty if `MODELLING_PLOTBEST` is true; if not, it displays only interval values that contain ± `MODELLING_SIGMAS` of the best models;
	- flow rate (in m3/s) is calculated in addition to volume variation;
	- volume variation unit is adjusted automatically (m3 or Mm3);
	- pCDM source type is now about a hundred times faster than previous versions.

### Others
Some other bug fixes and minor improvements.

## v2.1.2c (July, 2019)

### WEBOBS.rc
`!!` Default behavior does not show anymore a confirm 'alert' window if the action has succeed. For example, when editing a NODE or GRID configuration. If administrator wants the former behavior, he must set this new key:

```
CGI_CONFIRM_SUCCESSFUL|YES
```

All maps using SRTM DEM is now able to merge bathymetry data from ETOPO. Since this might require a minimum of RAM it is possible to disactivate it with the following key in `WEBOBS.rc` :

```
ETOPO_SRTM_MERGE|N
```
Also, to avoid memory issues with maps, a new key is defined:

```
DEM_MAX_WIDTH|1201
```
to automatically decimate any DEM before a plot. The parameter defines the square root of maximum total number of pixels (default corresponds to 1 SRTM3 tile).


### Events (Gazette, GRIDS and NODES)

Fix and improve of active group functionality in the Gazette (introduced in v2.0.0) and propagate to GRIDS and NODES events.

`!!` In order to limit the long list of users (that might include non-valid users) when creating a new event, new keys in `Gazette.rc`:

```
ACTIVE_GID|+ADMIN,+DUTY
```	
and in `WEBOBS.rc`:
 
```
EVENTS_ACTIVE_GID|+ADMIN,+DUTY
```

will display only users in the +ADMIN or +DUTY groups (valid or not), for new event in the gazette and in grids/nodes, respectively. Comment or empty these keys to keep the former behavior, i.e., display only the valid users.

As a reminder, once an event is created, editing it will allow selection of all existing users (list of valid first followed by invalid).


### Default group menus

`!!` Default additionnal menus will be added at upgrade if they do not exist yet for groups +ADMIN, +DUTY, +OBSERVER and +VISITOR. They contain usefull links for specific management. A menu is visible only by users associated to the corresponding group. Each menu can be modified or even removed by emptying it at edition.

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

4. Calibration file configuration has been moved from local config to the code distribution. The following are not used anymore and can be deleted:
	- file `CONF/CLB.conf`,
	- file `CONF/CLBFields.conf`,
	- key parameter `CLB_CONF` in `WEBOBS.rc`,
	- file `formule_calibration.html` in the HTML contents.

5. Multiple logos can be defined using coma-separated filenames in `LOGO_FILE` and `LOGO2_FILE` parameters. Logos with be horizontaly appended with same height.

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

1. `!!` `SUMMARYLIST` must now contain the keyword `SUMMARY` in the list of summary graphs to make the synthetic all node time series graph. In the former behavior, this summary graph was always made by default.

2. New GNSS data format `gipsyx` to read outputs from GipsyX 3rd party
software (see also next section).

3. `!!`	New key to select the misfit L-norm:

```
MODELLING_MISFITNORM|L1
```
which is L1-norm by default. To preserve the previous L2-norm in active
proc, this must be changed to `L2`.

4. `!!`	New key to limit numerical effets:

```
MODELLING_MINERROR_PERCENT|1
```
which set a minimum relative error of 1% (default) for each data before
computing the inverse problem. This is especially useful when there is 
a large number of stations (more than 10) and/or for long period of time
(more than 1 year). To get the exact previous behavior, this must be changed to `0`.

5. New keys to configure improved rendering of summary, pernode and baselines graphs:

```
COMPONENT_NAMELIST|Relative Eastern,Relative Northern,Relative Vertical
PERNODE_COMPONENT_OFFSET_M|0.01
PERNODE_TIMEZOOM|
SUMMARY_STATION_OFFSET_M|0.01
SUMMARY_COMPONENT_OFFSET_M|0.01
SUMMARY_TIMEZOOM|
BASELINES_REF_OFFSET_M|0.01
BASELINES_TIMEZOOM|
```
The `_TIMEZOOM` keys might contain a fraction number (between 0 and 1) which will produce a secondary subplot with a time zoom on the most recent data. For example, set `0.1` will make a zoom on the last 10% of data.

6. New key to configure the background basemap options for vectors:

```
VECTORS_DEM_OPT|'watermark',3,'interp','legend'
```
The list of options can be any valid parameters for `CODE/matlab/dem.m` function, such as changing the colormap and lighting effects.

7. Some fixes and improved modelling graphic outputs.


### superproc genplot

For consistency, two updates have been made in genplot superproc configuration, that might require administrators attention when upgrading.

1. `!!` The key `NODE_CHANNELS` has been renamed `PERNODE_CHANNELS` for consistency. Automatic update of any proc configuration will add the following:

```
PERNODE_CHANNELS|${NODE_CHANNELS}
```
so the former configuration should be kept. A good administrator practice is to replace the value manually and delete the obsolete `NODE_CHANNELS` key.

2. `!!` The key `SUMMARYLIST` must now be set to:

```
SUMMARYLIST|SUMMARY
```
to make the summary graph. Empty or commented parameter will lead to no summary graph. The former behavior was to activate the summary graph as the `SUMMARYLIST` key existed, even empty.

### GNSS GipsyX scripts

New bash shell scripts and configuration file `gnss_run_gipsyx ` and `raw2rinex` that use 3rd party programs JPL/GipsyX and Unavco/teqc to process GNSS rawdata 
and to produce PPP daily solutions in readable files architecture and names 
for the new WebObs `gipsyx` data format and superproc gnss.

Presently the raw formats accepted are *Leica*, *Trimble* and *Rinex* (standard or Hatanaka), eventually zipped, as daily or hourly files in subdirectories of any architecture using a combination of year, month, day, doy and station code. Multiple files for one day are concatenated.

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


### Superformat quakes

Solves a problem with `scevtlog-xml` format when some data don't have 
preferred magnitude. This affects all quake-compatible superprocs, in
particular hypomap and tremblemaps.
	
	
### Setup

Multiple fixes and improvements in installation.


### user registration

Fix register security issues and add possibility to change password.


## v2.1.0 (December, 2018)

### Sefran3

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

### Setup upgrade

When upgrading WebObs, the vimdiff of configuration files has been replaced
by a smarter tool: it detects automatically new keys between templates and
existing configuration and proposes to add new keys with comment into each
files and to edit each of them for double-check.
	
These operations can be refused by admin. In any case, the `SETUP.CONF.README`
file will contain the list of all new keys with explicit headers.


### Scheduler

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

### New users auto-registration

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
	

### All superprocs

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

### Superproc GNSS

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

### Superprocs hypomap and tremblemaps / quake data format

New filter (in addition to event type and status) applying on the 'comment'
field of event which corresponds to MC3 type if the catalog NODE has been
associated to an MC3 buletin (using `FID_MC3`):

```
EVENTCOMMENT_EXCLUDED_REGEXP|AUTOMATIC
```	
The filter is using case-insensitive regular expression pattern. Empty or
unset value won't filter any event.


### Gazette

In order to limit the long list of users (that might include unvalid users)
when creating a new event, a new key in Gazette.rc:

```
ACTIVE_GID|+DUTY
```	
will display only users in the +DUTY group (valid or not).

`!!`	To keep the former behavior (i.e., display only the valid users), you must comment or empty this key.

`!!`  NOTE: This functionality has been fixed in v2.1.2a.


-----------------------------------------------


