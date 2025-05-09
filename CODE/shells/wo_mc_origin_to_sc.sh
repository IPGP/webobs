#!/bin/bash

# SeisComP version
SeisComP_version=6

debug=0
test=0

while getopts "dth3" flag
do
    case "${flag}" in
        d) debug=1
        ;;
        t) test=1
        ;;
        3) SeisComP_version=3
        ;;
        h) echo "usage : cat QuakeML.xml | $0 -d -t -h"
        echo "  -d : debug mode"
        echo "  -t : test mode, do not send anything to SeisComP"
        echo "  -3 : target SeisComP3 (default SeisComP > 3)"
        echo "  -h : this help"
        exit 1
        ;;
    esac
done


scdispatch_options="--routingtable Pick:PICK,Amplitude:AMPLITUDE,Origin:LOCATION,StationMagnitude:MAGNITUDE,Magnitude:MAGNITUDE"

# Get spread and mysql server configurations
MESSAGING=$(seiscomp exec scdumpcfg global -P connection.server | grep value | cut -d ":" -f 2- | xargs echo -n)
if [ ${SeisComP_version} -gt 3 ]
then
    DB_PLUGIN=$(seiscomp exec scdumpcfg scmaster -P queues.production.processors.messages.dbstore.driver | grep value | cut -d ":" -f 2- | xargs echo -n)
    DB=$(seiscomp exec scdumpcfg scmaster -P queues.production.processors.messages.dbstore.read | grep value | cut -d ":" -f 2- | xargs echo -n)
    scdispatch_options="--no-events"
elif [ ${SeisComP_version} -eq 3 ]
then
    DB_PLUGIN=$(seiscomp exec scdumpcfg scmaster -P plugins.dbPlugin.dbDriver | grep value | cut -d ":" -f 2- | xargs echo -n)
    DB=$(seiscomp exec scdumpcfg scmaster -P plugins.dbPlugin.readConnection | grep value | cut -d ":" -f 2- | xargs echo -n)
    scdispatch_options="--routingtable Pick:PICK,Amplitude:AMPLITUDE,Origin:LOCATION,StationMagnitude:MAGNITUDE,Magnitude:MAGNITUDE,Event:NULL"
fi

# Convert QuakeML to the latest SeisComP ML
last_version=$(find ${SEISCOMP_ROOT}/share/xml/* -name "quakeml_1.2*" -type f -exec basename '{}' \; | sort -n -t '.' -k 3 | tail -n 1)
qml2scml=$(find ${SEISCOMP_ROOT}/share/xml -name ${last_version})
QML=$(mktemp /tmp/XXXXXX_qml.xml)
cat <&0 > ${QML}
SCML=$(mktemp /tmp/XXXXXX_scml.xml)

xsltproc ${qml2scml} ${QML} > ${SCML}

# Dispatch Origin to SeisComP
db_access=${DB_PLUGIN}://${DB}
if [ $debug -eq 1 ]
then
    cat ${SCML}
    scdispatch_options="${scdispatch_options} --debug"
fi
if [ $test -eq 1 ]
then
    scdispatch_options="${scdispatch_options} --test"
fi
seiscomp exec scdispatch -d ${db_access} -H ${MESSAGING} -i ${SCML} -O merge ${scdispatch_options}

rm ${SCML}
rm ${QML}
