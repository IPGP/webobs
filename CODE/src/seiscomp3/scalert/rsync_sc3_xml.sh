#!/bin/bash
#
# Script launched when creating or modifying an event, in order to export
# event database in QML format for WebObs (MC3).
#
#   - this script must be defined in /home/sysop/seiscomp3/etc/scalert.cfg.
#   - must use private/public ssh keys to allow access to webobs server.
#
# See http://www.seiscomp3.org/wiki/doc/applications/scalert for documentation.
#
# Author: Jean-Marie Saurel, Francois Beauducel / IPGP
# Updated: 2016-12-19


exec 2> /tmp/rsync_sc3_xml.log
printenv >&2

# Directory to be copied (seiscomp events in QML format)
EVENTS_QML_DIR="/home/sysop/seiscomp3/share/events"

# User and host of the disk server (mounted on webobs server)
DESTINATION_HOST="sysop@webobs"

# Destination path directory of the disk (must fit MC3.conf key SC3_EVENTS_ROOT)
DESTINATION_LOCATION="/home/wo/sefran/sc3_events/"

# Copy the QML files of seiscomp event to webobs 
rsync -av  $EVENTS_QML_DIR/ $DESTINATION_HOST:$DESTINATION_LOCATION

# Launch the MC3 update
ssh $DESTINATION_HOST "/opt/webobs/CODE/cgi-bin/seiscomp2mc3.pl update"
