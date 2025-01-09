#!/bin/bash
# Ojective: migration of existing former FORM (.DAT text file based) associated to
# PROCS, to GENFORM (.db based) associated to NODES (new grid FORM structure).
#
# Author: François Beauducel
# Created: 2024-04-21
# Updated: 2025-01-03


if [ -z "$1" ]; then
	echo
	echo "$0 migrates former FORM to new GENFORM"
	echo "Usage: $0 WOROOT"
	echo
	exit 1
fi

DRY_RUN=$2
# -----------------------------------------------------------------------------
function cmd {
	if [[ $DRY_RUN != 1 ]]; then
		echo $1
		eval $1
	else
		echo "(DRY RUN) $1"
	fi
}


# -----------------------------------------------------------------------------
if [[ $(id -u) != 0 && $DRY_RUN != 1  ]]; then
	echo 'Need to have root privileges. Bye'
	exit 64
fi

WOROOT=$1
DBF=$WOROOT/DATA/DB/WEBOBSFORMS.db
TMP=/tmp/webobs_genform_migration

P=`dirname $0`
if ! [[ -e $P/../dutils.sh ]]; then
	echo 'Missing dutils.sh. Bye.'
	exit 64
fi
. $P/../dutils.sh

if [[ -z ${RELBASE} ]]; then
	RELBASE="$P/../.."
fi

wousr=$(stat -f '%Su' $WOROOT/CONF/GRIDS2NODES)
wogrp=$(stat -f '%Sg' $WOROOT/CONF/GRIDS2NODES)


# =============================================================================
# make a loop on all PROC associated to FORM
for p in $(ls $WOROOT/CONF/GRIDS2FORMS/); do
 
	# -----------------------------------------------------------------------------
	# get the names of proc, form and nodes
	proc=$(echo $p | cut -d '.' -f 2)
	form=$(echo $p | cut -d '.' -f 3)
	nodes=()
	for n in $(ls -d CONF/GRIDS2NODES/PROC.$proc*); do
		nodes+=($(echo $n | cut -d '.' -f 3))
	done
	RE=$(printf "|%s" ${nodes[@]})
	RE=${RE:1}

	# will process only known forms...
	#if [[ $form =~ ^DISTANCE|BOJAP|EAUX|EXTENSO|FISSURO|GAZ|RIVERS|SOILSOLUTIONS$ ]]; then
	if [[ $form =~ ^EAUX$ ]]; then

		echo "---> Migrating PROC '$proc' to GENFORM"
		echo " FORM = $form"
		echo -n " NODES ="
		printf " %s" ${nodes[@]}
		echo ""

		# -----------------------------------------------------------------------------
		# make the form conf
		if [[ $form == $conf ]]; then
			dconf0="$WOROOT/CONF/FORMS/${form}_LEG"
			cmd "mv $WOROOT/CONF/FORMS/$form $dconf0"
		else
			dconf0="$WOROOT/CONF/FORMS/$form"
		fi
		dconf1="$WOROOT/CONF/FORMS/$proc"
		confp="$WOROOT/CONF/PROCS/$proc/$proc.conf"
		conf0="$dconf0/$form.conf"
		conf="$dconf1/$proc.conf"

		# database table (lowercase proc name)
		DBT=$(echo "$proc" | tr '[:upper:]' '[:lower:]')

		# data filename
		DAT="$WOROOT/DATA/DB/"$(grep ^FILE_NAME $conf0 | cut -d '|' -f 2)

		if [[ ! -e "$DAT" ]]; then
			echo "** Warning: no data FILE_NAME found in $conf0... nothing to do!"
			continue
		fi

		cmd "mkdir -p $dconf1" 

		echo  " Creating/populating $DBT table with former $DAT ($dconf0)..."

		# -- start SQL script
		echo "BEGIN TRANSACTION;" > $TMP
		echo "DROP TABLE if exists $DBT;" >> $TMP
		printf "CREATE TABLE $DBT (id integer PRIMARY KEY AUTOINCREMENT, trash boolean DEFAULT FALSE, quality integer, node text NOT NULL" >> $TMP
		printf ", edate datetime, edate_min datetime, sdate datetime NOT NULL, sdate_min datetime, operators text NOT NULL" >> $TMP
		printf ", comment text, tsupd text NOT NULL, userupd text NOT NULL" >> $TMP

		case "$form" in
			"EAUX")
				NBI=23

				# uses French or English template
				if grep -iq "^TITLE.*eaux" $conf0; then
					TEMPLATE="WATERS_fr"
				else
					TEMPLATE="WATERS"
				fi

				# copy template files
				cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
				cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE.*.conf $dconf1/"

			 	# ID|Date|Heure|Site|Type|Tair (°C)|Teau (°C)|pH|Débit (l/min)|Cond. (°C)|Niveau (m)|Li|Na|K |Mg|Ca|F |Cl|Br|NO3|SO4|HCO3|I |SiO2|d13C|d18O|dD|Remarques|Valider
			 	# 1 |2   |3    |4   |5   |6        |7        |8 |9            |10        |11        |12|13|14|15|16|17|18|19|20 |21 |22  |23|24  |25  |26  |27|28       |29
				for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
				echo ");" >> $TMP
				tac $DAT | grep -E "$RE" | iconv -f ISO-8859-1 -t UTF-8 | gawk -F'|' -v t="$DBT" -v n="$NBI" ' { if ($1 != "ID") { \
					bin = ($1<0) ? 1:0; \
					printf "INSERT INTO "t"(trash,quality,node,edate,edate_min,sdate,sdate_min,operators,comment,tsupd,userupd"; \
					for (i=1;i<=n;i++) printf ",input%02d",i; \
					printf ") ";\
					printf "VALUES(\""bin"\",\"1\",\""$4"\",\""$2" "$3"\",\""$2" "$3"\",\"\",\"\""; \
					gsub(/"/,"\"\"", $28); \
					gsub(/\045/,"\045\045", $28); \
					if ($29 ~ /^\[.*\] /) {
						nn = split($29,vv,/\] \[/);
						split(vv[1],v," ");
						gsub(/\[/, "", v[1]); \
						gsub(/\]/, "", v[2]); \
						printf ",\""v[2]"\",\""$28" "$29"\",\""v[1]"\",\""v[2]"\"" \
					} else { printf ",\"!\",\""$28" "$29"\",\"\",\"\"" }; \
					for (i=5;i<n+5;i++) printf ",\""$i"\""; \
					print ");" }}' >> $TMP 
				;;
		esac
		
		# -- end of SQL script
		echo "COMMIT;" >> $TMP
		cmd "cat $TMP | sqlite3 $DBF && rm -f $TMP" 

		# copy some variable values from former FORM and PROC conf
		v=$(grep ^TITLE\| $conf0 | iconv -f UTF-8 -t ISO-8859-1)
		cmd "LC_ALL=C sed -i -e 's/^NAME|.*$/$v/g;s/^TITLE/NAME/g' $conf"
		for key in BANG DEFAULT_DAYS; do
			cmd "LC_ALL=C sed -i -e 's/^$key|.*$/$(grep ^$key\| $conf0)/g' $conf"
		done

		for key in TZ OWNCODE TYPE URL COPYRIGHT NODE_NAME NODE_SIZE NODE_MARKER NODE_RGB DEM_FILE DEM_TYPE DEM_COPYRIGHT; do
			v=$(grep '^$key|' $confp)
			if [ ! -z $v ]; then
				cmd "LC_ALL=C sed -i -e 's/^$key|.*$/$v/g' $conf"
			fi
		done

		cmd "chown -R $wousr:$wogrp $WOROOT/CONF/FORMS/$proc" 

		# -----------------------------------------------------------------------------
		# make the new links form2nodes
		for n in ${nodes[@]}; do
			cmd "ln -sf $WOROOT/DATA/NODES/$n $WOROOT/CONF/GRIDS2NODES/FORM.$proc.$n" 
		done
		cmd "chown $wousr:$wogrp $WOROOT/CONF/GRIDS2NODES/FORM.$proc.*" 
	fi
	echo "Done."

done

exit 1



