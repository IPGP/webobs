#!/bin/bash

BEGIN="2013-01-01 00:00:00"
END="2013-12-31 00:00:00"
SC3_DB_HOST="piccard"
SC3_DBNAME="seiscomp3"
SC3_DB_USER="sysop"
SC3_DB_PASS="sysop"

seiscomp3/bin/seiscomp exec scevtls -d mysql://${SC3_DB_USER}:${SC3_DB_PASS}@${SC3_DB_HOST}/${SC3_DBNAME} --begin "${BEGIN}" --end "${END}" > /tmp/event.list

while read event
	do
	seiscomp3/bin/seiscomp exec scxmldump -d mysql://${SC3_DB_USER}:${SC3_DB_PASS}@${SC3_DB_HOST}/${SC3_DBNAME} -pmPAM -E $event -o /tmp/sc3.xml
	yyyymmdd=`cat /tmp/sc3.xml | sed -rn 's/.*<EventParameters>(.*)<creationTime>(.*)T(.*)Z<\/creationTime>(.*)/\2/p'`
	year=`echo $yyyymmdd | cut -d "-" -f 1`
	month=`echo $yyyymmdd | cut -d "-" -f 2`
	day=`echo $yyyymmdd | cut -d "-" -f 3 | cut -c 1-2`
	mkdir -p sc3_events/$year/$month/$day/$event
	seiscomp3/bin/seiscomp exec scxmldump -d mysql://${SC3_DB_USER}:${SC3_DB_PASS}@${SC3_DB_HOST}/${SC3_DBNAME} -fpmPAM -E $event -o sc3_events/$year/$month/$day/$event/$event.last.xml
	done < /tmp/event.list

