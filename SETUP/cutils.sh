#!/bin/bash

# WEBOBS main configuration file (WEBOBS.rc) utilities, to be used from WEBOBS release 'SETUP/upgrade'.
# Helps with changing/adding configuration file entries (ie. key|value lines)
# To be sourced once at beginning of the 'WEBOBS configuration upgrade process' 
# Apply changes to /etc/webobs.d/WEBOBS.rc or user specified configuration file. 
# Internally uses a 'bash-variables' view of WEBOBS.rc perl's hash (thru exposerc.pl)

woconf() {
	# internal: (re)-loads WEBOBS.rc as the set of bash variables WO__webobskeys
	unset $(/usr/bin/env | egrep '^WO__' | /usr/bin/cut -d= -f1)
	oIFS=${IFS}; IFS=$'\n'
	LEXP=($(perl /etc/webobs.d/../CODE/cgi-bin/exposerc.pl '=' 'WO__'))
	for i in $(seq 0 1 $(( ${#LEXP[@]}-1 )) ); do export ${LEXP[$i]}; done
	IFS=${oIFS}
}

# unconditionnaly sets WEBOBS.rc as WO__* env variables when this script is loaded
woconf;

cptr() {
# internal: checks for / resolves conf file indirection:
# if argument is prefixed with '+', attempts to return value of key 'argument'
# if no '+' returns argument unchanged
# used to return either 1) a conf filename overriding /etc/webobs.d/WEBOBS.rc, 
# or 2) a conf filename pointed to by an /etc/webobs.d/WEBOBS.rc key (indirection)
# eg. cptr +CONF_SCHEDULER
#     ==> if 'CONF_SCHEDULER|SCHED.rc' then evaluates to SCHED.rc else evaluates to CONF_SCHEDULER
	if [ $# -eq 1 ]; then 
		if [ ${1:0:1} == "+" ]; then
			xx="WO__${1:1}"
			if [ .${!xx} == . ]; then echo ${1:1}; else echo ${!xx}; fi
		else
			echo ${1}
		fi
	fi
}

conf_renamekey() {
	# external: rename a key, leaving its current value unchanged
	# 2 req'd arguments + 1 optional :
	# 1 : the key to be renamed ( without ending | )
	# 2 : the key new name (without ending | )
	# 3 : optional fullname of config file or +indirect-key
	# eg. conf_renamekey OBSERVATOIRE OBS 
	#     ==> 'OBSERVATOIRE|something' changed to 'OBS|something'
	if [ $# -ge 2 ]; then
		local conf="/etc/webobs.d/WEBOBS.rc"
		[ $# -eq 3 ] && conf=$(cptr ${3})
		perl -i -n -w -e "if (/^${1}\|(.*)\$/) {print \"${2}|\$1\n\"} else { print \"\$_\"}" ${conf}
		echo "conf_renamekey: ${1} ==> ${2}  [ in ${conf} ]"
		woconf;
	fi
}

conf_replacekey() {
	# external: replace full key|value definition line, add replacement line if key|value doesn't exist
	# 2 req'd arguments + 1 optional :
	# 1 : key ( without ending | ) identifying the line to be replaced
	# 2 : replacement line (new key|value)
	# 3 : optional fullname of config file or +indirect-key
	# eg. conf_replacekey VERSION "#VERSION commented out" 
	#     ==> 'VERSION|1.1.1' changed to '#VERSION commented out'
	if [ $# -ge 2 ]; then
		local conf="/etc/webobs.d/WEBOBS.rc"
		[ $# -eq 3 ] && conf=$(cptr ${3})
		#dbg# echo perl -i -p -w -e "s/^${1}.*$/${2}/g" ${conf} 
		perl -i -p -w -e "s/^${1}.*$/${2}/g" ${conf} 
		echo "conf_replacekey: ${1} ==> ${2}  [ in ${conf} ]"
		grep "^${2}" ${conf} 1>/dev/null 2>&1 || (echo ${2} >> ${conf} && echo " ( ${2} was added )")
		woconf;
	fi
}

conf_addkey() {
	# external: add a 'key|value' line if it doesn't exists yet
	# 1 req'd argument + 1 optional :
	# 1 : the key|value line to be added
	# 2 : optional fullname of config file or +indirect-key 
	# eg. conf_addkey "NEWKEY|VALUE" W.rc
	#     ==> in W.rc, adds line 'NEWKEY|VALUE'
	if [ $# -ge 1 ]; then
		local conf="/etc/webobs.d/WEBOBS.rc"
		[ $# -eq 2 ] && conf=$(cptr ${2})
		grep "^${1}" ${conf} 1>/dev/null 2>&1 || echo ${1} >> ${conf}
		echo "conf_addkey: ${1}  [ in ${conf} ]"
		woconf;
	fi
}

conf_deletekey() {
	# external: delete a 'key|somevalue' line
	# 1 req'd argument + 1 optional:
	# 1 : the key ( without ending | ) of line to be deleted 
	# 2 : optional fullname of config file or +indirect-key 
	# eg. conf_deletekey "OLDKEY" 
	#     ==> deletes line 'OLDKEY|something'
	if [ $# -ge 1 ]; then
		local conf="/etc/webobs.d/WEBOBS.rc"
		[ $# -eq 2 ] && conf=$(cptr ${2})
		sed -i "/^${1}/ d" ${conf}
		echo "conf_deletekey: ${1}  [ in ${conf} ]"
		woconf;
	fi
}

