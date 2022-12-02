# WEBOBS RELEASE NOTES

## Important note
This document contains install/upgrade summary and specific instructions for users and administrators.

The latest release contains improvements, new features, bug fixes, and sometimes security strengthening.
**Upgrade is recommended for all WebObs administrators**. For known issues, please take a look to [github.com/IPGP/webobs/issues](https://github.com/IPGP/webobs/issues) and do not hesitate to submit any problem with this release.

Sections with `!!` prefix must be carefully read in case of upgrade. It usually means that the upgrade could change some behavior from previous release installations (not a bug fix). An appropriate configuration to keep former behavior is usually proposed.

## Version under development
### New features

1. Node's automatic geographical positioning using automatic KML feed is possible by selecting **auto KML feed** in positioning type. It uses a new node's variable `POS_RAWKML` containing a URL that returns a KML content. Latitude, longitude, altitude and positioning date will be filled and updated from *Placemark/TimeStamp/when* and *Placemark/Point/coordinates* tags.
`!!` The local data configuration **CONF/POSITIONtypes.conf** pointed by `FILE_POS` variable in **NODE.rc** is now obsolete and unused. It is replaced by the read-only file **CODE/etc/postypes.conf**. If some administrators have modified the original template by adding new positioning types, please open an issue or contact the dev team.


### Enhancements
1. In the **Scheduler Runs**:
    -  possibility to select a job ID and to sort any column in the job runs table.
    - ``!!`` access is now submitted to authorization rights. Resource is *scheduler* in the *misc* table. Admin (4) is needed to delete a log date or kill a running job.

### Fixed issues
1. We started to improve *GNU Octave* compatibility of the *Matlab* code. Since *Octave* has a less permissive grammar, it lead to a better writing and sometimes hidden bug fixes. See the associated [discussion thread](https://github.com/IPGP/webobs/discussions/116).

## v2.5.3 (September 2022)

### New features

1. In the superproc **gnss**, new functionality available to apply a harmonic sine+cosine correction on the signal for each component (E,N,U). This can be used to remove a priori periodic signal like atmospheric or ocean loading. New parameters are:
    - `HARMONIC_ORIGIN_DATE` for the date/time of phase origin for all sine and cosine,
    - `HARMONIC_PERIOD_DAY` list of harmonic periods, coma separated values, in days (example: `365.25,182.625` for 1 year and 6 months),
    - `HARMONIC_EAST_SINCOS_MM`, `HARMONIC_NORTH_SINCOS_MM`, `HARMONIC_UP_SINCOS_MM` contain pairs of sine,cosine amplitudes for each period, in mm.
To activate the correction, all parameters must be valid and number of pairs must be consistent with the number of periods for all components.

1. Also in superproc **gnss**, new options for velocity trends:
    - `VECTORS_AMPLITUDE_COMPONENTS` defines the used components to compute velocity amplitudes and plot the amplitude vs distance plot (summary graph VECTORS). Default is `1,2` for horizontal components only. Set this option to `3` to use only the vertical component.
    - `TREND_MIN_PERCENT` sets a minimum threshold of time period with data to compute a trend. Default is 50%.

1. GNSS thing again, new shell script `gnss_make_rinex` and its config file `gnss_make_rinex.rc` to build rinex files from different formats of raw data and sitelog files.

1. In the superproc **genplot**, per node graph can plot several moving averages using `MOVING_AVERAGE_SAMPLES` with coma separated values of samples. A shading color scale will be used.

1. In addition to map location node, a list of active neighbour nodes is automatically displayed, sorted by decreasing distances and indicating direction and elevation gain. A link to each neighbour nodes is available, with a warning icon when a project is associated to this node. Two new parameters are added to **NODES.rc** configuration file: `NEIGHBOUR_NODES_ACTIVE_ONLY` (default is `Y`) and `NEIGHBOUR_NODES_MAX` (default is 15) to limit the number of displayed nodes.

1. Former *Google Maps API* for grids and nodes has been replaced by *OpenStreetMap* free mapping (layers taken from https://leaflet-extras.github.io/leaflet-providers/preview/):
    - **ESRI World Imagery**: mix of satellite images
    - **OpenTopoMap**: topography with contour lines and roads
    - **OpenStreetMap**: the collaborative project world map
    - **Stamen Terrain**: hill shading and natural vegetation colors
    - **Stamen Watercolor**: just for fun...
The new GUI uses https://leafletjs.com javascript application.

1. Any grid or node's page shows a QRcode containing URL address of the page. The code can be printed in a new window with associated logos defined in **WEBOBS.rc** `QRCODE_LOGOS` variable. `QRCODE_SIZE` defines the code module size (in pixels, default is 2, empty or zero to disable the display). This function needs the installation of **qrencode** utility on the server (`sudo apt install qrencode`).

1. Node-feature-node association can be edited using the node configuration form: each feature can be associated to another node or list of nodes, creating a parent-children link through this feature. This functionality was already existing but only editable by administrator. If the list of features is modified, a refresh icon allows to update the list of feature/node association text forms. The interface still requires to enter the node ID codes. The former link to edit the **node2node.rc** global file has been removed. It can be added in the +ADMIN menu, as a new entry like `<li><a href="/cgi-bin/xedit.pl?fs=CONF_NODES(FILE_NODES2NODES)">node2node.rc</a></li>`.

1. In **Sefran/MC**, keyboard shortcuts can be defined by administrator to select the event type and amplitude during phase picking, as an alternative to menu list mouse selection. The key must be a single character, case sensitive, defined in the **MC3_Codes.conf** file as a new column with name `KBcode` in the header line `=key|...`. Example:
    ```
    =key|Name|Color|BgColor|Md|asVT|asRF|Location|WO2SC3|KBcode
    UNKNOWN|Unknown event|\#535353|\#FFFFFF|-1|0|0|1|1|
    VOLCTECT|Volcano-Tectonic|\#FA8072|\#FFFFFF|0|1|0|1|1|V
    VOLCLP|Volcanic Long-Periode|\#DC143C|\#FFFFFF|0|0|0|1|1|L
    ...
    ```
    to set key `V` (uppercase) for event type **VOLCTECT** and key `L` for event type **VOLCLP**.
    For amplitudes, the format is similar but without the functional `=key` header:
    ```
    # Key|Name|Value|KBcode
    WEAK|Weak|0|1
    AVERAGE|Average|500|2
    STRONG|Strong|1000|3
    OVERSCALE|Overscale|2000|4
    ```
    to set numbers 1 to 4 for amplitudes **WEAK** to **OVERSCALE**, respectively.
    Note that letters `e`, `r`, `t`, `s` and `S` are already assigned to functions (show/hide MC events and spectrogram control). The `Enter` key submit the form.

1. Node's events are shown as background areas in graphs (per node only, not in summary graphs). New variables in **NODES.rc**: `EVENTNODE_PLOT_COLOR` to set the color (default is `Silver`), `EVENTNODE_PLOT_LINEWIDTH` to set the line width for "instant" events (default is 1), and `EVENTNODE_PLOT_OUTCOME_ONLY` to select only events having the flag 'sensor/data outcome' ON (default is `YES`). Presently this functionality is available for superprocs **genplot**, **afm**, **gnss**, **tilt**, **jerk**, **rsam**, and **meteo**.

### Enhancements

1. In nodes event editing, the date and time formats are now checked. When editing an existing event, it is now possible to move the event to another node (you must know the target's node ID).

2. It's now possible to directly download proc requests results in .tgz file at results page, and a link to the scheduler run log is available.

3. New options in the Search node events tool:
    - grids column is now optional (checkbox) and desactivated by default,
    - full node name can be displayed (checkbox),
    - a link allows to download a .csv file of the results,
    - a wait icon appears during the search.

4. Proc request form proposes the last user's date intervals as preset dates (will fill-up the date/time fields).

5. All nodes have a time zone parameter associated to lifetime dates and events date/time. Default (undefined) time zone will be considered as GMT. Any node configuration edit will propose the time zone of the server.

1. Improves the form behaviour in node configuration edit:
    - features former delimiters (escaped characters like \, or \|) are replaced by coma,
    - negative latitude or longitude is allowed in node geographic location. A negative value will automatically switch the N/S or E/W selection.

1. `!!` Event mail notification now contains the full message. It is possible to keep the former behavior (event's title only) by setting the new **WEBOBS.rc** variable `EVENTS_NOTIFY_FULL_MESSAGE` to `NO`.

### Fixed issues

1. The search event fonction is now working with grid's name.

2. Some fixes in proc request results display.

3. Improves boolean parameters reading in Perl scripts (accepts case insentitive 0/N/NO or 1,Y,YES).

4. Users list in grid/node event editor is now sorted in alphabetic order of UID (previously it was based on the login name, case sensitive).

1. Other minor fixes.


## v2.4.2 (November 2021)

### New features

1. An automatic classification of seismic event type in the Sefran/MC has been implemented. It uses the code **Automatic Analysis Architecture** by M. Malfante, J. Mars, and M. Dalla Mura [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.1216028.svg)](https://doi.org/10.5281/zenodo.1216028). Installation procedure, configuration and usage are described in [pse_configuration.md](https://github.com/IPGP/webobs/blob/master/DOC/pse_configuration.md) readme file.

2. Two new forms have been created: **SOILSOLUTION** (soil solution chemical analysis) and **RAINWATER** (rain water chemical analysis). Databanks can be created using specific editor forms, display table and graphs (presently the genplot). When upgrading, the `setup` will copy the templates in the local CONF directory.


### Enhancements

1. superproc **hypomap** has a new variable to select events `EVENTCOMMENT_INCLUDED_REGEXP` containing a regular expression applied to each event comment string. It can be used to select type(s) of event from MC3, since the comment field contains the event type full name from associated MC3. Example:
    ```
    EVENTCOMMENT_INCLUDED_REGEXP|Volcano-Tectonic\|Long Period
    ```
    To select events of types **Volcano-Tectonic** and **Long Period**. Note the pipe `|` must be escaped with a backslash `\|`.

2. superproc **gnss** has new features for summary graph MODELTIME:
    - a new variable `MODELTIME_SOURCE_TYPE` now allowing the pCDM source in model time series. An additional graph will be made with name **MODELTIME_pCDM**. Use `isotropic,pcdm` value to compute both types of sources (separated graphs). **Warning:** the computation of pCDM source can be very long: about a minute for a single 2,5 million points model, so detailed model time series on several periods may take hours of computation. Use `MODELTIME_MAX_MODELS` to limit the computation (time step will be adjusted automatically, overwriting the `MODELTIME_SAMPLING_DAY` value).
    - a new variable to fix Y-axis of plots: `MODELTIME_FLIM` containing min,max values for source flow rate (in m<sup>3</sup>/s) or volume variation (in m<sup>3</sup>), depending on the `MODELTIME_FLOWRATE` option. Empty value stands for automatic scale which is the default and former behaviour.
    - a new variable `DISP_YSCALE_M` to fix the displacement Y-scale on some graph (in meter). Default is automatic.

3. `!!` Any **sefran3** is now managed as a new type of GRID, beside VIEW and PROC.
    - It can be associated to a DOMAIN and will be displayed in the table of grids, with optional type/owner and links to SEFRAN3 main page and associated MC3.
    - A new sefran can be created from templates using the create/edit GRID form. A specific page of configuration allows edition of the main configuration files: `SEFRAN3.conf` and `channels.conf` which are stored in a specific directory in the new `$WEBOBS{PATH_SEFRANS}/*` structure.
    - When upgrading, existing sefrans must be manually associated to a domain to appear in the grid table (use the Domain manager). `setup` will **NOT** move existing configuration files from the original CONF directory; only symbolic links will be created.
    - The variable `CHANNEL_CONF` remains operational for backward compatibility, pointing to any channels' configuration file, but it is recommended to remove/comment it so sefran will use implicitly the unique `channels.conf` file.
    - Authorization for a sefran is managed using the **procs** auth table and sefran name as resource. The generic `MC` resource name remains functional for all sefrans.

4. `!!` Still for **sefran3**, former configuration file `SEFRAN3_TimeIntervals.conf` and corresponding variable `TIME_INTERVALS_CONF` become obsolete and might be deleted; they are replaced by a new variable `TIME_INTERVALS_LIST` in `SEFRAN3.conf` (coma-separated list of time intervals in hours, 0 stands for "Last MC events"), with default list of values that might be edited if necessary:  
    ```
    TIME_INTERVALS_LIST|0,6,12,24,48,168
    ```

5. `!!` Directory of proc's binaries has been moved from `${ROOT_CODE}/matlab/bin` to `${ROOT_CODE}/bin`. This affects only the distributed package since binaries are ignored by git. Symbolic links have been created to preserve existing configuration when upgrading, but administrators are encouraged to edit `WEBOBS.rc` and remove the `matlab/` sub-directory in the MCC path variable, for example in the case of linux-64 architecture, it should be like:
    ```
    PATH_MCC|${ROOT_CODE}/bin/linux-64
    ```

6. **User's** have now two new attributes for account administration (editabled through the User Manager GUI):
    - an **expiry date** of validity in the format `YYYY-MM-DD` as the last effective day of the account activity (reference is the WebObs server local time). Let this field empty for potentially never-ending accounts. Combined with a validity flag `Y`, if the expiry date is passed the user will be still considered as invalid. A validity flag `N` always invalidates the account whatever the expiry date is.
    - a **comment** field (free string) to add any useful information about the account (only seen by admins). When a new user has auto-registered, this field is used to add the date and time of registering.

### Fixed issues
1. **sefran3**: There was a problem with the last binary with seedlink and fdsnws-dataselect protocols if one or more data channels are missing (error). Also the variable `NAME` was not used (still former obsolete `TITRE`)
2. **mc3**: It was impossible to select a time period within the last day of the month.
3. `!!` **SRTM tiles for mapping**: Following the fix in 2.3.3, an USGS mirror site has been restored to continue the benefits of downloading automatically new SRTM3 global topographic data without the need to register at the NASA/EarthDATA center. Nevertheless, the authentication is still needed for SRTM1 tiles download (option `DEM_SRTM1|Y`). As a reminder, downloaded tiles are stored locally in the `PATH_DATA_DEM_SRTM` directory (in **WEBOBS.rc**, default is `/opt/webobs/DATA/DEM/SRTM`), and used to update maps without requiring new download from the internet. Thus, a possible alternative to registering at EarthDATA is to place here all the needed tiles manually (must be in the `.hgt` format, filename in the form `[N|S]yy[E|W]xxx.hgt[.zip]` for LAT yy and LON xx at lower-left corner of the tile).
4. all maps: an uggly artifact might appended on coast lines with `ETOPO_SRTM_MERGE|Y`.
1. fix an issue in events display for grids with an underscore in the name.


## v2.3.3 (February 2021)

### New features

1. `!!` The `LD_LIBRARY_PATH` environment variable is now automatically reset for commands run from a Matlab process to allow commands to be run in a normal system environment. This means that administrators do not need to reset this variable in `PRGM_*` variables defined in `WEBOBS.rc` like it was previously required in most environments (these variables should now simply include the command name, using either their short name or an absolute path). In particular, **the value of `PRGM_CONVERT` advised in the release notes for version 2.2.0 will not work with this version**: if you upgrade from 2.2.0, please make sure `PRGM_CONVERT` only points to the convert command like this :
    ```
    PRGM_CONVERT|convert
    ```
   (using a value of `export LD_LIBRARY_PATH='' && convert` **will NOT work**, but the previous default value of `env LD_LIBRARY_PATH='' /usr/bin/convert` will work, althought redefining `LD_LIBRARY_PATH` is not required any more.)

2. A new script `SETUP/compress-sefran-parallel` is provided to replace the previous script `SETUP/compress-SEFRAN` described in the release notes for version 2.2.0 below to compress the existing PNG images produced by the Sefran, while retaining the tags in the images.
    * Run `SETUP/compress-sefran-parallel -h` to learn about available options and to get help on the different ways to use the script.
    * This script can provide the same functionality as `SETUP/compress-SEFRAN`, but it will not show the percentage of the progression. It will however (by default) show the names of the processed files.
    * If the `parallel` command is installed on the system, compressions will be executed in parallel (2 by default, but this can be changed using the `-j` option if more than 2 CPU are available and your system is not overloaded);
    * This script can also be used by advanced users to export the minimalistic bash function `run_pngquant` into the current shell that can then be _manually_ fed with a list of files to compress. This functionality can be useful to compress fewer files at a time to not overload the system for too long (e.g. to process a limited number of sefran images during nighttime). It can also be used to compress images exported on a different system not running WebObs (the system will still need `imagemagick`, `pngquant`, and optionnally `parallel` installed). Run the script with the `-h` option to learn more about this functionality. An example of such advanced use to only process one month of images with 4 concurrent compressions would be (note that the use of `sort` is only useful to visually control the progression of the compressions from the dates in the names of the files being compressed):
        ```
        $ . /opt/webobs/WebObs-2.3.0/SETUP/compress-sefran-parallel load_env
        $ find /srv/sefran/201901* -name '*.png' | sort | parallel -j 4 run_pngquant
        ```

3. The **GNSS superproc** has new features for the summary graph **MODELLING**:
   * `MODELLING_SOURCE_TYPE` now accepts a list of coma-separated models, i.e., presently only `isotropic` and `pCDM`. If two models are defined, both will be computed and available through menu links **MODELLING** and **MODELLING_pCDM**, respectively.
   * `MODELLING_EXCLUDED_FROM_TARGET_KM` now accepts negative value to exclude nodes at distance *lower* than the absolute value, i.e., `-5` will exclude stations up to 5 km from the target. As a reminder, a positive value will exclude nodes at distance *greater* than the value.
   * `MODELLING_INCLUDED_NODELIST` allows to include node(s) that have been (eventually) excluded by the previous parameter or by `MODELLING_EXCLUDED_NODELIST`.
   * `!!` `MODELLING_ENU_ERROR_RATIO` is a list of 3 factors applied to the velocity trend components E, N, and U, respectively, before the modelling process. The default is `1,1,2` to multiply by 2 the vertical component errors, which is more consistent with the usual GNSS data errors. Set to `1,1,1` to keep the previous behavior and results.

4. The **GNSS superproc** has new summary graph **MODELNET**, which analyses the network sensitivity as capacity to estimate source volume variation at depth. The graph shows horizontal slices of minimum volume variations detectable by a minimum number of stations simultaneously, giving a minimum displacement for each component E,N,U. The calculation will consider only stations that are active within the graph time scale. New parameters are:

   * `MODELNET_EXCLUDED_NODELIST`, `MODELNET_EXCLUDED_FROM_TARGET_KM`,
`MODELNET_INCLUDED_NODELIST` to select the stations (same rules as for **MODELLING**).
   * `MODELNET_MIN_DISP_MM` defines the minimum displacements as an error ellipsoid semi-axis vector of E,N,U components in mm (default is 1 mm for horizontal components, and 2 mm for vertical component).
   * `MODELNET_MIN_STATION` sets the minimum number of stations (default is 2).
   * `MODELNET_DEPTH_SLICE` is the vector of depth slices (default is 5 slices from 0 to 8 km depth).
   * `MODELNET_BORDERS` sets additional border (in m) around the stations to define the grid map (default is 1 km).
   * `MODELNET_TARGET_INCLUDED` when set to `Y` includes target `GNSS_TARGET_LATLON` in the grid.
   * `MODELNET_GRID_SIZE` sets the grid size (default is 100 pixels).
   * `MODELNET_VIEW_AZEL` sets the 3D view parameters as azimuth,elevation in degree (default is 40° azimuth, 10° elevation).
   * `MODELNET_DVLIM` sets the volume variation colorbar limits as dVmin,dVmax in m<sup>3</sup> (default is automatic).
   * `MODELNET_COLORMAP` sets the colormap (default is scientific colormap **roma** from F. Crameri).
   * `MODELNET_MARKER` sets the plot parameters for station markers (default is white triangle).
   * `MODELNET_TITLE` sets the graph title.

   When upgrading, these lines will be added to any existing gnss procs:
   ```
   MODELNET_EXCLUDED_NODELIST|
   MODELNET_EXCLUDED_FROM_TARGET_KM|
   MODELNET_INCLUDED_NODELIST|
   MODELNET_MIN_DISP_MM|1,1,2
   MODELNET_MIN_STATION|2
   MODELNET_DEPTH_SLICE|0:2000:8000
   MODELNET_BORDERS|1000
   MODELNET_TARGET_INCLUDED|Y
   MODELNET_GRID_SIZE|100
   MODELNET_VIEW_AZEL|40,10
   MODELNET_DVLIM|
   MODELNET_COLORMAP|roma(256)
   MODELNET_MARKER|'^k','MarkerSize',6,'MarkerFaceColor',.99*ones(1,3)
   MODELNET_TITLE|{\fontsize{14}{\bf${NAME} - Network sensitivity}}
   ```
5. **Node calibration file** is now associated to procs, and not unique anymore. Each proc will use its own calibration table for a given node. For backwards compatibility, the following behavior is adopted:
   * any existing calibration file (created before this release 2.3.0) will continue to apply to any proc associated to the node, as a default.
   * when edited through a particular proc, the former calibration file is duplicated and the edited version will remain specific to the corresponding proc and not affect others that will continue to use the former version of the calibration file, until it is edited.
   * when creating a new calibration file, it will be uniquely associated to the proc under which it is created, and only visible and used by this proc. Other procs will still consider there is no calibration file for the node, until it is created.

6. The raw data format **dsv** (text delimiter separated values) does not require anymore a calibration file for each node. In case of missing calibration file, a default name will be given to each data channel. Also, it has new possible parameters (editable through node's configuration):
   * `FID_DATACOLS` is an index vector of the file columns that contain the imported data. The default, and former behavior, is an automatic detection of the data (all but the date and time columns).
   * `FID_ERRORCOLS` is an index vector of the file columns defining the data errors in the same order as data. It must have the same length as data vector. Use 0 to skip a column if no error is associated to it. Default (empty) won't associate any error with the data. Columns of errors are ignored in the data automatic detection mode.

7. New CSS classes have been created to allow presenting graphs in nice frames on the welcome page, but it can be used anywhere in WebObs pages. Refer to the **Welcome_news.txt** default file for a sample use of these classes.

### Fixed issues
1. `!!` To continue the benefits of downloading automatically new SRTM3 global topographic data, WebObs administrator must now register to NASA/EarthDATA center at https://urs.earthdata.nasa.gov (free). A single valid login (user `usr` and password `pwd`) must be obtained then stored in one of the following:
	* `WEBOBS.rc` configuration file as variable:
	   ```
       EARTHDATA_LOGIN|usr,pwd  
       ```
	* or in the WebObs owner user's home (default is **wo**), adding the 3 lines in `/home/wo/.netrc` (auto-login process):
        ```
        machine urs.earthdata.nasa.gov
        login usr
        password pwd
        ```
    This authentication will be used for both SRTM3 and SRTM1 1°x1° tiles download. As a reminder, downloaded tiles are stored locally in the `PATH_DATA_DEM_SRTM` directory (default is `/opt/webobs/DATA/DEM/SRTM`), and used to update maps without requiring new download from the internet. Thus, a possible alternative to registering at EarthDATA is to place here all the needed tiles manually (must be in the `.hgt` format).

2. When using Firefox 79+ (and potentially recent versions of other browsers), the temporary tab was not automatically closed and the event log not refreshed after editing an event in the event log / _main courante_.

3. In the **GNSS** superproc, there was a mistake in the name of parameter to adjust velocity scale manually in **VECTORS** graph: the correct name is `VECTORS_VELOCITY_SCALE` and defines the velocity in mm/yr corresponding to 25% of the graph width.

4. The wpage.pl script that shows the content of `Wiki` and `HTML` pages now correctly detects and displays HTML-only content (it was previously resulting in an invisible content, which was still editable though).

5. Fix in **dsv** rawdata format (was not able to read the last column).

6. First try to include Winston format in **Sefran3** data source (was missing)

## v2.2.0 (November 2020)

### New features

1. `!!` **Sefran3** includes a continuous spectrogram, which is activated by default. To disable this feature you must set `SGRAM_ACTIVE|NO` in all your Sefran3. Since the feature uses new Perl, JavaScript and CSS, if you notice any strange display you must **clear your browser cache**, this will solve the problem definitively.

    New variables are:

    ```
    PATH_IMAGES_SGRAM|sgram
    SGRAM_ACTIVE|Y  
    SGRAM_FILTER|hpbu6,0.1
    SGRAM_PARAMS|0.5,0,50,lin
    SGRAM_EXPONENT|0.5
    SGRAM_COLORMAP|spectral(256)
    SGRAM_CLIM|0,2
    SGRAM_OPACITY|0.7
    PNGQUANT_NCOLORS|16
    SGRAM_PNGQUANT_NCOLORS|32
    ```

Default values are optimized for 100 Hz sampling rate:
- `SGRAM_FILTER`: signal filtering, same syntax as for `SEFRAN3_CHANNELS` file (default is `hpbu6,0.1` for a highpass Butterworth 6th-order 0.1 Hz cut-off frequency filter);
- `SGRAM_PARAMS`: 4-element vector of coma separated values, as:
   - W = time step window for FFT (in seconds, default is 0.5 s),
   - Fmin = minimum frequency (in Hz, default is 0 Hz),
   - Fmax = maximum frequency (in Hz, default is 50 Hz),
   - Yscale = `lin` for linear (default) or `log` (logarithmic);
- `SGRAM_EXPONENT`: power spectrum amplitude exponent (default is 0.5);
- `SGRAM_COLORMAP`: colormap (default is spectral);
- `SGRAM_CLIM`: 2-element vector as minimum, maximum values for colormap limits (default is 0-2, which corresponds to a saturation of the spectrogram colors when the signal is also saturated on the waveforms);
- `SGRAM_OPACITY`: initial opacity of spectrogram over waveform image (default is 0.5).

When the spectrogram is activated, minute and hourly images are made at low and high speed simultaneously with classical waveform images, and updated following broom wagon rules. The additional computing time is not significant. But, a spectrogram image are about 1.5 times bigger than waveform's images (low+high speed total). For that reason, we introduced a better compression of all PNG images using open-source program *pngquant*, with a gain of about 70% in size (see next section for details). Final result is a reduction of Sefran3 storage size after activating the spectrogram! ;-)

For visualization, there is several possibilities:
- a new icon is available in the main page menu or in the upper-left control panel to toggle waveform/spectrogram view;
- the control panel includes also a manual slide range button to control opacity of the spectrogram;
- hot key 'S' can be press anytime to toggle waveform/spectrogram view at default or current opacity value;
- hot key 'Shift-S' forces the spectrogram view at maximum opacity (no transparency);
- hot keys 'R' to lower transparency by 1/10 step (increases opacity), and 'T' to increase by 1/10 (decreases opacity);
- hot keys 'E' or 'e' have been added to toggle MC event tags display.

   Hot keys are disabled when editing the event form; you must click outside the field inputs to reactivate them.

2. Another **sefran3** improvement: PNG images are now compressed using the external program *pngquant*, which optimizes the colormap. Gain of size on Sefran3 images is about 70%. It is strongly recommended to install the utility (`apt install pngquant`), which is set in a new WEBOBS.rc variable `PRGM_PNGQUANT`. If the program exists, it will automatically compress the new images (waveforms and spectrograms). Two additionnal variables in SEFRAN3.conf are:
    ```
    PNGQUANT_NCOLORS|16
    SGRAM_PNGQUANT_NCOLORS|32
    ```

where `PNGQUANT_NCOLORS` is the number of colors for waveform compression (default is 16), and `SGRAM_PNGQUANT_NCOLORS` the number of colors for spectrogram compression (default is 32). These values can be reduced to make smaller files, but this might produce unwanted solarization effects, especially visible on the spectrogram.

A known issue is an error in sefran3 using *convert* program, due to missing dynamic library. This might be solved in this version 2.2.0 by the following `WEBOBS.rc` variable:

```
PRGM_CONVERT|export LD_LIBRARY_PATH=''; /usr/bin/convert
```
> **Attention**: this value of `PRGM_CONVERT` is specific to WebObs version 2.2.0 and **will not work in versions >= 2.3.0**, where a more general approach was implemented. Please refer to the release notes of 2.3.0 for more details.

We also propose a bash script `SETUP/compress-SEFRAN` to compress existing sefran3 archives. A basic benchmark shows that a single full year of sefran3 archive may take over a day of processing on a standard computer, but a reduction of about 70% of the total size of archive. Administrators who want to make their own compression must be aware that unfortunately, *pngquant* ignores user's tag header written in the original PNG file. To rewrite the Sefran3 tags in compressed files (needed by broom wagon and display of data statistics), you might use the program `identify` to export tags from the original file first, then `convert` to rewrite them in the compressed file:

```
tag=$(identify -format %[sefran3*] $INPUT | sed -e 's/sefran3/ -set sefran3/g;s/=/ /g' | tr -d '\n')
cat $INPUT | pngquant 16 | convert - $tag $OUTPUT
```

These two lines make the core of `compress-SEFRAN` script.

### Enhancements

1. Proc's main page (cgi-bin/showGRID.pl) displays two additional tables in the *Specification* section:
- one table of main available proc's output page links sorted by time scales (Overview and Summary plots);
- one table of time scale parameters as defined in the configuration. This may help to check if some parameters are undefined.

2. `!!` Superproc GNSS has new variable to adjust errors on data for different orbits: `ORBIT_ERROR_RATIO` which contains a vector of ratios associated to orbit values 0 (final), 1 (rapid), and 2 (ultra), respectively. The default setting of the new variable is:
    ```
    ORBIT_ERROR_RATIO|1,2
    ```
   and will multiply by 1 final-orbit errors (orbit = 0), and by 2 any non-final orbits (orbit > 0). Set this variable empty, or 1 to keep previous behavior.

3. Since 2020, there no more free access website where SRTM1 tiles can be downloaded anonymously. If you have already used SRTM1 data in your procs, the tiles have been stored in your `PATH_DATA_DEM_SRTM1` and are still available offline for mapping on the corresponding areas. But to download new tiles or at first install, you now need to register at [earthdata.nasa.gov](https://urs.earthdata.nasa.gov) (free). User and password login must be specified in a new variable `EARTHDATA_LOGIN` in `WEBOBS.rc`:
    ```
    EARTHDATA_LOGIN|user,password
    ```

   If this login is not defined, SRTM3 tiles will be used whatever `DEM_SRTM1` value is.

4. Superproc TILT has two new parameters for modelling:
    ```
    MODELLING_MISFITNORM|L1
    MODELLING_APRIORI_HSTD_KM|
    ```

    as for the GNSS superproc modelling, `MODELLING_MISFITNORM` allows L1 (default) or L2 norm to compute misfit. `MODELLING_APRIORI_HSTD_KM` will apply a gaussian function on the global misfit based on the distance from target defined in `TILT_TARGET_LATLON`.

5. Mapping benefits the new feature of dem.m function: the color saturation. Superprocs GNSS, HYPOMAP, TILT and TREMBLEMAPS can include the option in their respective `*DEM_OPT` variables as `'Saturation',0.7` for example, to reduce saturation by 30%. For the superproc GRIDMAPS, a new variable has been added to `GRIDMAPS.rc`:
    ```
    COLOR_SATURATION|0.7
    ```
    **Tip:** maps are usually used as a background to highlight other elements (stations, vectors, ...). The mapping concept in WebObs is to keep plain colors for these elements, and attenuate the background colors using two parameters: a watermark effect (set to a factor of 1.5 by default) and now the saturation effect (set to 0.5 by default).

6. Two new scientific colormaps are available: `ryb` and `spectral`. `ryb` is a diverging colormap where luminance is highest at the midpoint, and decreases towards differently-colored endpoints (Red-Yellow-Blue). It is set as new default for GNSS modelling probability graphs. `spectral` is a Red-Orange-Yellow-Green-Blue colormap  `jet` but less saturated/agressive and with constant luminance. It has been set as default for most of the procs and the Sefran3 spectrogram.

### Fixed issues

1. Due to a discrepancy in data class between `sefran3.m` and `rdmseed.m`, sefran3 was not able to use data input other than standard Steim1/2 coding. This has been fixed.

2. In GNSS/GispyX data format, station code is now case insensitive. In fact, station code in `.tdp` files is written upper case, so lower case FID were not properly found in the GipsyX solutions. This has been fixed.

3. The [Codemirror javascript library](https://codemirror.net/) (used to colorize the textareas used to edit configuration file for procs and nodes) embedded in WebObs has been updated to address the security issue described in [CVE-2020-7760](https://nvd.nist.gov/vuln/detail/CVE-2020-7760).


## v2.1.6 (September 2020)

### Enhancements

1. The Scheduler now listens for control commands throught UDP on the `127.0.0.1` local address by default. This will restrict control of the Scheduler to local users only. If you really want to allow other users on the network to access this interface, set the `LISTEN_ADDR` configuration variable to another configured IP address or corresponding hostname in the Scheduler configuration file (by default `scheduler.rc`). In this case, it is advised to limit access to specific hosts using local firewall rules.

2. A new option `MERGE_JOB_LOGS` in the scheduler configuration file (by default `scheduler.rc`) allows to merge the standard output and standard error outputs of the jobs to a common file using the name set in the `logpath` field of the job definition, suffixed by `.log`. If `MERGE_JOB_LOGS` is `y`, `yes`, (case insensitive) or `1`, the output will be merged, otherwise the scheduler follows the historical behaviour and will write the outputs to files respectively suffixed by `.stdout` and `.stderr`.

3. The `setup` script now checks if your system uses the system and service manager _systemd_, and will propose to install or update the service definition files `woscheduler.service` and `wopostboard.service` if necessary, adapting the provided templates to your environment as needed.  The templates files for these systemd services have also been updated.  For further details about WebOBs _systemd_ integration, please refer to the new section `4.4 Postboard and Scheduler system integration` of the WebObs manual.

4. The HTML interface in the Scheduler Manager and the User Manager now uses checkboxes to control the _validity_ field in the job, user, and notifications forms. If you experience some abnormal behaviour (e.g. if the 'validity' checkbox isn't checked when it should), try clearing your browser cache (the javascript and CSS files might not correctly be refreshed).

5. Some bug and security issues were fixed in the Scheduler Runs and Scheduler Manager CGI scripts. It is advised to update your WebObs installation with this release.

### Fixed issues

1. For users using _systemd_, the commands `systemctl stop woscheduler` and `systemctl stop wopostboard` no longer mark the related service as _failed_ as `postboard.pl` and `scheduler.pl` now report a clean exit when stopped through a TERM signal. (Note that the command `sudo systemctl stop woscheduler` will cleanly stop the Scheduler, but running jobs will be killed. If you want to stop the Scheduler after waiting for all the jobs to finish, use the command `/opt/webobs/CODE/shell/scheduler stop`. The systemd service will stop normally when the process exits.)

2. The `scheduler` helper script was not able to start or control the Scheduler on systems where the `netstat` command is missing (on newer systems it is by default replaced by `ss` from the `iproute` toolbox).

3. The postboard and its helper function `WebObs::Config::notify` were rejecting notifications having an empty 4th field (`message` field), although action notifications should rightfully be accepted with no parameters, and therefore with an empty `message` field.

4. When specifying the email address of a webobs user as Envelope From address in a mailing notification submitted to the postboard, the full name of the user and its email address were mistakenly inverted, using something like `john.doe@example.com <John Doe>` instead of `John Doe <john.doe@example.com>` as the `From:` field.

5. When editing a node from an associated view, if this node was also associated with procs, the parameters (FID, FNDS network, etc.) were lost.

6. An issue using the 'replay mode' in Sefran/MC when not using the default sefran3.


## v2.1.5b (August 2020)

### Enhancements

1. Grid's configuration uses a VIM editor with syntax highlighting. New WEBOBS.rc keys:
    ```
    JS_EDITOR_EDIT_THEME|default
    JS_EDITOR_BROWSING_THEME|neat
    JS_EDITOR_AUTO_VIM_MODE|no
    ```

2. Sefran now uses full functionality of `DATASOURCE` variable (Seedlink, Arclink, FDSNWS)

3. MC can handle multiple associated images for each event (still undocumented)

4. GNSS modelling has additional node exclusion filter (distance from target, if defined by `GNSS_TARGET_LATLON`), and fixed scale capability for vectors plot. New keys are:
    ```
    MODELLING_EXCLUDED_FROM_TARGET_KM|
    MODELLING_VMAX_MM|0
    MODELLING_VMAX_RATIO|.25
    MODELLING_VECTORS_CLIP|NO
    ```

5. Proc request form now includes a "verbose logs" option (debug mode)

6. sefran3.pl now accepts a 'hideloc' CGI parameter similar to the 'hideloc'
   parameter of mc3.pl. If its value is 1, event locations will not be shown in
   the popovers of events in the hourly thumbnail view (which allows the page
   to load faster, especially when using FDSNWS). If not present, its value
   defaults to the inverted value of `MC3_EVENT_DISPLAY_LOC` from the Sefran
   configuration.

7. The MC now includes a calculation of energy in joules, shown for each event
   in a popover in the 'Magnitude' column. The total energy of selected events
   is also shown in the top section of the MC, and two new graphs are
   available: one shows the energy in joules featuring each type of event, the
   other only plots the total energy of all event types.

8. Several improvements in the form EAUX: the list of nodes now uses a fixed
   order, and the entry filters are kept after adding/modifying a new entry to
   ease the entry/modification of new data.


### Fixed issues

1. all procs: cannot change default colormap (Matlab and .cpt file) with `*_COLORMAP` keys

2. all procs: fdsnws-event data format failed in associating MC3 event types

3. gridmaps: secondary maps crashed with inactive nodes in grid

4. mc3stats: improper default values

5. some issues with grid associated to more than one domain

6. `!!` scripts showOUTG.pl and showOUTR.pl did not use proper configuration variables. Added in `WEBOBS.rc`:
    ```
    URN_OUTG|/OUTG
    URN_OUTR|/OUTR
    ```

    `!!` A new alias `/OUTR` must be added in the Apache configuration:
    ```
	Alias /OUTR /opt/webobs/OUTR
    ```
    or, for non default configurations, `URN_OUTG` pointing to `ROOT_OUTR`.

7. sefran3 new event window did not close after validation with the latest version of some web browsers (Firefox, Safari).

8. Properly hide trashed events from the Sefran hour view for admin users when the 'trash' checkbox is unchecked in the Sefran hour thumbnail page.

9. Fix redirection error when creating or deleting a folder in the 'wiki' pages.

10. Fix two bugs in the miniseed output of seismic events (available from the MC or the Sefran pages) when using FDSNWS. Also fix the error page display when the miniseed file could not be fetched.


See github commits for details.

## v2.1.4c (January 2020)

### Sefran

In the event editing window, two new buttons in the control left upper menu allow to scroll back or forward the signal window of one minute.

### Superproc gnss

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

    `MAFILTER` is a moving-average filter with default 10 samples. `MOTION_SCALE_MM` can be used to fix the displacement scale corresponding to 30% of the map width (default `0` is automatic).

2. The target (defined by `GNSS_TARGET_LATLON` coordinates) is systematically included in the summary graphs `MODELLING` and `MODELTIME`. It is possible to add it into `VECTORS` and `MOTION` summary graphs with new variables:
    ```
    VECTORS_TARGET_INCLUDED|Y
    MOTION_TARGET_INCLUDED|Y
    ```

3. The graphs per node can include a principal component analysis subplot by setting a negative value for key:
    ```
	PERNODE_TIMEZOOM|-1
    ```
	with some options:
    ```
    PERNODE_PCA_COLOR|0.3,0.6,0
    PERNODE_PCA_MAFILTER|10
    ```

### Superproc tilt

Component azimuth from calibration file are now taken into account. Pernode graphs are still showing original components, but summary graphs are using projected components in an orthogonal NS-EW referential.

New summary graph MOTION showing spatial time evolution of tilt at each station. Associated variables are:

```
SUMMARYLIST|MOTION
MOTION_EXCLUDED_NODELIST|
MOTION_MAFILTER|
MOTION_SCALE_RAD|
MOTION_MIN_SIZE_KM|
MOTION_COLORMAP|
MOTION_DEM_OPT|
MOTION_TITLE|
```


### Gridmaps

New default behavior for multiple grid maps: node aliases located into submaps defined by `MAP1_XYLIM`, `MAP2_XYLIM`, ...  are not shown in the main map and any previous submap. This can be used to avoid text overlap with node swarms. Former behavior can be retrieved using following variable in the grid's configuration:

```
NODE_SUBMAP_ALIAS|Y
```

### Proc requests

A new option "Anonymous" is available to remove the subtitle with user's name in the produced graphs.

A bug has been fixed in the request results table to show correctly the job status (wait..., ok or error).

### Administration

1. User's form now allows edition of associated group(s). Associated users in group edition form is still allowed.

2. New tool to edit domains: creation, edition, and grid association.

### GNSS GipsyX scripts

1. new default option in .rc to force delta antenna to zero (avoid offsets when rinex headers are not consistent)

2. `raw2rinex` now manages any gzipped data files (.gz)


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

All maps using SRTM DEM is now able to merge bathymetry data from ETOPO. Since this might require a minimum of RAM it is possible to disable it with the following key in `WEBOBS.rc` :

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

`!!` Default additional menus will be added at upgrade if they do not exist yet for groups +ADMIN, +DUTY, +OBSERVER and +VISITOR. They contain useful links for specific management. A menu is visible only by users associated to the corresponding group. Each menu can be modified or even removed by emptying it at edition.

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

3. NODE alias that contains an underscore character is now written
normally in the graphs title or label (no TeX interpretation as
subscribe position for the next character). TeX formatting is still
possible in the graph title, any channel, NODE or PROC names. To display an underscore character in these strings, you must escape it (`\_`).

4. Calibration file configuration has been moved from local config to the code distribution. The following are not used anymore and can be deleted:
	- file `CONF/CLB.conf`,
	- file `CONF/CLBFields.conf`,
	- key parameter `CLB_CONF` in `WEBOBS.rc`,
	- file `formule_calibration.html` in the HTML contents.

5. Multiple logos can be defined using coma-separated filenames in `LOGO_FILE` and `LOGO2_FILE` parameters. Logos with be horizontally appended with same height.

### Sefran/MC

Dumping data bulletin and opening miniseed files now open a new empty
window or tab in the browser.

In the MC table, a new *View* icon indicates now that user can only view an event and not modifying it. Only editable events show the *Edit* icon.

`!!`	Dump .csv bulletin file now includes one additional column with event
	ID as `"yyyy-mm#id"` in the last column.

`!!`	Users with *Edit-level* authorization are now able to edit any event
	of the reserved type **AUTO**. They are still NOT allowed to modify other
	types of event, excepted if they own the event itself.

### New superproc mc3stats

This new alpha-version superproc reads seismic catalogs from Main Courante and plot some elaborated statistics. The PROC must be associated to a catalog NODE with FID as MC3_NAME. Undocumented yet.

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

4. `!!`	New key to limit numerical effects:

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
