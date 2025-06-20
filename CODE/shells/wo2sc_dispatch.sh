#!/bin/bash
#
# This script loads configuration defined in WEBOBS.rc file into the current
# environment as variables prefixed by 'WO__'.
# It then loads MC3.conf files into the current environment as variables 
# prefixed by 'MC3_'.
# Based on information in provided MC3.conf, it triggers a dispatch script
# on a SeisComP server, thus creating a new origin.

usage() {
    cat <<EOF
Usage : $(basename "$0") /path/to/MC3.conf
EOF
    exit 1
}

# Check parameter
[[ ${1:-} =~ ^(-h|--help)$ ]] && usage
[[ $# -ne 1 ]] && { echo "Error : you must provide a MC3.conf." >&2; usage; }
CONF_FILE=$1
[[ ! -r ${CONF_FILE} ]] && { echo "Error : file ${CONF_FILE} not found or not readable" >&2; exit 2; }

# Load WEBOBS.rc variables
source /etc/webobs.d/../CODE/shells/readconf

# Load the MC3 variables
oIFS=${IFS}; IFS=$'\n'
LEXP=($(gawk -F '|' '!/^(#|$|\r|=)/{gsub(/WEBOBS{/,"{WO__",$2);if(length($2)>1)printf("MC3_%s=%s\n",$1,$2)}' ${CONF_FILE} | dos2unix))
for i in $(seq 0 1 $(( ${#LEXP[@]}-1 )) ); do export ${LEXP[$i]}; done
IFS=${oIFS}

# Make sure to force a second expansion (for variables containing variables)
QML_TEMP_FILE=$(eval "printf '%s\n' "${MC3_WO2SC_QML_TEMP_FILE}"")
SSH_KEY=$(eval "printf '%s\n' "${MC3_WO2SC_SSH_KEY}"")

# Creates log file and logs the dispatch command used on the SeisComP side.
echo "Dispach command : ${MC3_WO2SC_DISPATCH_SCRIPT_PATH}" > ${WO__ROOT_LOGS}/wo2sc.log

# Use SSH key file if provided
SSH_OPTS=""
[[ -n ${SSH_KEY} ]] && SSH_OPTS="-i ${SSH_KEY}"

# Check if required vars are set
required_vars=(MC3_WO2SC_USER MC3_WO2SC_HOSTNAME MC3_WO2SC_DISPATCH_SCRIPT_PATH QML_TEMP_FILE)
for v in "${required_vars[@]}"; do
    if [[ -z ${!v:-} ]]; then
        echo "Error : var $v is undefined or empty ; exiting." >&2
        exit 3
    fi
done

# Check if QML_TEMP_FILE exists and is readable
if [[ ! -r "${QML_TEMP_FILE}" ]]; then
    echo "Error : QML temporary file ${QML_TEMP_FILE} does not exist or is unreadable." >&2
    exit 4
fi

# Triggers the dispatch script on the SeisComP side
cat ${QML_TEMP_FILE} | /usr/bin/ssh ${SSH_OPTS} ${MC3_WO2SC_USER}@${MC3_WO2SC_HOSTNAME} "${MC3_WO2SC_DISPATCH_SCRIPT_PATH}" >> ${WO__ROOT_LOGS}/wo2sc.log 2>&1

# Cleaning
rm ${QML_TEMP_FILE}
