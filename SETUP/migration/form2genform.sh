#!/bin/bash
# Ojective: migration of existing former FORM (.DAT text file based) associated to
# PROCS, to GENFORM (.db based) associated to NODES (new grid FORM structure).
#
# Author: François Beauducel
# Created: 2024-04-21
# Updated: 2025-01-24


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
	if [[ $DRY_RUN != 1 && ! -z "$1" ]]; then
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

today=$(date)

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

FPATH=$WOROOT/CONF/FORMS
LFPATH=$WOROOT/CONF/LEGACY_FORMS
LFDB=$WOROOT/DATA/BACKUP_LEGACY_FORMS
cmd "mkdir -p $LFPATH/FORMS $LFPATH/GRIDS2FORMS $LFDB"

# =============================================================================
# make a loop on all known legacy FORMs
#for form in EAUX RIVERS SOILSOLUTIONS RAINWATER EXTENSO FISSURO GAZ DISTANCE BOJAP 
for form in EAUX_DEMO; do
    
    # -----------------------------------------------------------------------------
    # test if a legacy form might exist...
    conf="$WOROOT/CONF/FORMS/$form/$form.conf"
    if [[ ! -e "$conf" ]]; then
        continue
    fi
    FDAT=$(grep ^FILE_NAME $conf | cut -d '|' -f 2)
    DAT="$WOROOT/DATA/DB/"$(grep ^FILE_NAME $conf | cut -d '|' -f 2)
    if [[ -z "$FDAT" || ! -e "$DAT" ]]; then
        echo "---> No legacy data found in $conf... nothing to do for $form."
        continue
    fi
        
    # move the legacy conf and data first
    cmd "mv -f $FPATH/$form $LFPATH/FORMS/"
    conf0="$LFPATH/FORMS/$form/$form.conf"

    # make a loop on all PROCs associated to this FORM
    for p in $(ls -d $WOROOT/CONF/GRIDS2FORMS/PROC.*.$form); do
    
        # -----------------------------------------------------------------------------
        # get the names of proc, form and nodes
        proc=$(echo $p | cut -d '.' -f 2)
        nodes=()
        for n in $(ls -d CONF/GRIDS2NODES/PROC.$proc*); do
            nodes+=($(echo $n | cut -d '.' -f 3))
        done
        RE=$(printf "|%s" ${nodes[@]})
        RE=${RE:1}

        echo "---> Migrating PROC '$proc' to GENFORM"
        echo " FORM = $form"
        echo -n " NODES ="
        printf " %s" ${nodes[@]}
        echo ""

        # -----------------------------------------------------------------------------
        # make the form conf
        dconf1="$WOROOT/CONF/FORMS/$proc"
        confp="$WOROOT/CONF/PROCS/$proc/$proc.conf"
        conf="$dconf1/$proc.conf"

        # database table (lowercase proc name)
        DBT=$(echo "$proc" | tr '[:upper:]' '[:lower:]')


        cmd "mkdir -p $dconf1" 

        echo  " Creating/populating $DBT table with former $DAT..."

        # -- start SQL script
        echo "BEGIN TRANSACTION;" > $TMP
        echo "DROP TABLE if exists $DBT;" >> $TMP
        printf "CREATE TABLE $DBT (id integer PRIMARY KEY AUTOINCREMENT, trash boolean DEFAULT FALSE, quality integer, node text NOT NULL" >> $TMP
        printf ", edate datetime, edate_min datetime, sdate datetime NOT NULL, sdate_min datetime, operators text NOT NULL" >> $TMP
        printf ", comment text, tsupd text NOT NULL, userupd text NOT NULL" >> $TMP

        case "$form" in
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "EXTENSO")
                NBI=22
                ICOM=37
                IVAL=38

                # uses French template
                TEMPLATE="EXTENSO_fr"

                # copy template files
                cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
                cmd "cp $RELBASE/CODE/tplates/FORM_$TEMPLATE*.conf $dconf1/"

                # ID|Date|Heure|Site|Opérateurs|Température|Météo|Ruban|Offset|F1|C1|V1|F2|C2|V2|F3|C3|V3|F4|C4|V4|F5|C5|V5|F6|C6|V6|F7|C7|V7|F8|C8|V8|F9|C9|V9|Remarques|Validation
                # 1 |2   |3    |4   |5         |6          |7    |8    |9     |10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37       |38
                for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
                echo ");" >> $TMP
                tac $DAT | grep -E "$RE" | iconv -f ISO-8859-1 -t UTF-8 | gawk -F'|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,edate,edate_min,sdate,sdate_min,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\",\""$2" "$3"\",\""$2" "$3"\",\"\",\"\",\""$5"\""; \
                    gsub(/"/,"\"\"", $ic); gsub(/\045/,"\045\045", $ic); \
                    if ($iv ~ /^\[.*\] /) { \
                        nn = split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""$ic" "$iv"\",\""v[1]"\",\""v[2]"\"" \
                    } else { printf ",\""$ic" "$iv"\",\"\",\"\"" }; \
                    for (i=6;i<10;i++) printf ",\""$i"\""; \
                    for (i=10;i<35;i+=3) {
                        j = i+1; k = i+2;
                        d = $i + $j;
                        printf ",\""d"\",\""$k"\""; \
                    }
                    print ");" }}' >> $TMP 
                ;;
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "EAUX_DEMO")
                NBI=23
                ICOM=28
                IVAL=29

                # uses French or English template
                if grep -iq "^TITLE.*eaux" $conf0; then
                    TEMPLATE="WATERS_fr"
                else
                    TEMPLATE="WATERS"
                fi

                # copy template files
                cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
                cmd "cp $RELBASE/CODE/tplates/FORM_$TEMPLATE*.conf $dconf1/"

                # ID|Date|Heure|Site|Type|Tair (°C)|Teau (°C)|pH|Débit (l/min)|Cond. (°C)|Niveau (m)|Li|Na|K |Mg|Ca|F |Cl|Br|NO3|SO4|HCO3|I |SiO2|d13C|d18O|dD|Remarques|Valider
                # 1 |2   |3    |4   |5   |6        |7        |8 |9            |10        |11        |12|13|14|15|16|17|18|19|20 |21 |22  |23|24  |25  |26  |27|28       |29
                for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
                echo ");" >> $TMP
                tac $DAT | grep -E "$RE" | iconv -f ISO-8859-1 -t UTF-8 | gawk -F'|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,edate,edate_min,sdate,sdate_min,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\",\""$2" "$3"\",\""$2" "$3"\",\"\",\"\""; \
                    gsub(/"/,"\"\"", $ic); gsub(/\045/,"\045\045", $ic); \
                    if ($iv ~ /^\[.*\] /) { \
                        nn = split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\""$ic" "$iv"\",\""v[1]"\",\""v[2]"\"" \
                    } else { printf ",\"!\",\""$ic" "$iv"\",\"\",\"\"" }; \
                    for (i=5;i<n+5;i++) printf ",\""$i"\""; \
                    print ");" }}' >> $TMP 
                ;;
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "RIVERS")
                NBI=18
                ICOM=23
                IVAL=24

                TEMPLATE="RIVERS"

                # copy template files
                cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
                cmd "cp $RELBASE/CODE/tplates/FORM_$TEMPLATE*.conf $dconf1/"

                # ID|Date|Hour|Site|Level|Type|Flask|Twater (C)|Suspended Load|pH|Conductivity at 25C|Conductivity|Na|K |Mg|Ca|HCO3|Cl|SO4|SiO2|DOC|POC|Comment|Validate
                # 1 |2   |3   |4   |5    |6   |7    |8         |9             |10|11                 |12          |13|14|15|16|17  |18|19 |20  |21 |22 |23     |24
                for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
                echo ");" >> $TMP
                tac $DAT | grep -E "$RE" | iconv -f ISO-8859-1 -t UTF-8 | gawk -F'|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,edate,edate_min,sdate,sdate_min,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\",\""$2" "$3"\",\""$2" "$3"\",\"\",\"\""; \
                    gsub(/"/,"\"\"", $ic); gsub(/\045/,"\045\045", $ic); \
                    if ($iv ~ /^\[.*\] /) { \
                        nn = split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\""$ic" "$iv"\",\""v[1]"\",\""v[2]"\"" \
                    } else { printf ",\"!\",\""$ic" "$iv"\",\"\",\"\"" }; \
                    for (i=5;i<n+5;i++) printf ",\""$i"\""; \
                    print ");" }}' >> $TMP 
                ;;
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "GAZ")
                NBI=17
                ICOM=22
                IVAL=23

                # uses French or English template
                if grep -iq "^TITLE.*gaz" $conf0; then
                    TEMPLATE="VOLCGAS_fr"
                else
                    TEMPLATE="VOLCGAS"
                fi

                # copy template files
                cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
                cmd "cp $RELBASE/CODE/tplates/FORM_$TEMPLATE*.conf $dconf1/"

                # Id|Date|Heure|Site|Tfum|pH|Debit|Rn|Amp|H2|He|CO|CH4|N2|H2S|Ar|CO2|SO2|O2|d13C|d18O|Observations|Valider
                # 1 |2   |3    |4   |5   |6 |7    |8 |9  |10|11|12|13 |14|15 |16|17 |18 |19|20  |21  |22          |23
                for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
                echo ");" >> $TMP
                tac $DAT | grep -E "$RE" | iconv -f ISO-8859-1 -t UTF-8 | gawk -F'|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,edate,edate_min,sdate,sdate_min,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\",\""$2" "$3"\",\""$2" "$3"\",\"\",\"\""; \
                    gsub(/"/,"\"\"", $ic); gsub(/\045/,"\045\045", $ic); \
                    if ($iv ~ /^\[.*\] /) { \
                        nn = split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\""$ic" "$iv"\",\""v[1]"\",\""v[2]"\"" \
                    } else { printf ",\"!\",\""$ic" "$iv"\",\"\",\"\"" }; \
                    for (i=5;i<n+5;i++) printf ",\""$i"\""; \
                    print ");" }}' >> $TMP 
                ;;
        esac
        
        # -- end of SQL script
        echo "COMMIT;" >> $TMP
        cmd "cat $TMP | sqlite3 $DBF && rm -f $TMP" 

        # -----------------------------------------------------------------------------
        # copy some variable values from former FORM and PROC conf
        v=$(grep ^TITLE\| $conf0 | sed -e 's/&/\\&/g' | iconv -f UTF-8 -t ISO-8859-1)
        cmd "LC_ALL=C sed -i -e 's/^NAME|.*$/$v/g;s/^TITLE/NAME/g' $conf"
        for key in BANG DEFAULT_DAYS; do
            okey=$(grep ^$key\| $conf0)
            if [[ ! -z "$okey" ]]; then
                cmd "LC_ALL=C sed -i -e 's/^$key|.*$/$okey/g' $conf"
            fi
        done

        for key in TZ OWNCODE TYPE URL COPYRIGHT NODE_NAME NODE_SIZE NODE_MARKER NODE_RGB DEM_FILE DEM_TYPE DEM_COPYRIGHT; do
            v=$(grep '^$key|' $confp)
            if [ ! -z $v ]; then
                cmd "LC_ALL=C sed -i -e 's/^$key|.*$/$v/g' $conf"
            fi
        done

        # -----------------------------------------------------------------------------
        # add default data format to the PROC conf
        cmd "LC_ALL=C sed -i -e 's/^RAWDATA|.*//g;s/^RAWFORMAT|.*//g' $confp" # removes any RAWFORMAT/RAWDATA
        cmd "echo '################################################################################' >> $confp"
        cmd "echo '# Migrate legacy form $form to new FORM.$proc on $today' >> $confp"
        cmd "echo 'RAWFORMAT|genform' >> $confp"
        cmd "echo 'RAWDATA|$proc' >> $confp"
        cmd "echo '################################################################################' >> $confp"

        cmd "chown -R $wousr:$wogrp $WOROOT/CONF/FORMS/$proc" 

        # -----------------------------------------------------------------------------
        # make the new links form2nodes
        for n in ${nodes[@]}; do
            cmd "ln -sf $WOROOT/DATA/NODES/$n $WOROOT/CONF/GRIDS2NODES/FORM.$proc.$n" 
        done
        cmd "chown $wousr:$wogrp $WOROOT/CONF/GRIDS2NODES/FORM.$proc.*" 
        
        # -----------------------------------------------------------------------------
        # finally moves legacy conf 
        cmd "mv $WOROOT/CONF/GRIDS2FORMS/PROC.$proc.$form $LFPATH/GRIDS2FORMS/"
        cmd "mv $DAT $LFDB/"

        echo "Done."
    done
done

exit 1



