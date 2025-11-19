#!/bin/bash
# Ojective: migration of existing former FORM (.DAT text file based) associated to
# PROCS, to GENFORM (.db based) associated to NODES (new grid FORM structure).
#
# Author: François Beauducel, Jérôme Touvier
# Created: 2024-04-21
# Updated: 2025-07-03


if [[ -z "$1" ]]; then
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
    #exit 64
fi

today=$(date)

WOROOT=$1
DBD=$WOROOT/CONF/WEBOBSDOMAINS.db
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

if stat --version >/dev/null 2>&1; then
    # GNU stat
    wousr=$(stat -c '%U' $WOROOT/CONF/GRIDS2NODES)
    wogrp=$(stat -c '%G' $WOROOT/CONF/GRIDS2NODES)
else
    # BSD stat
    wousr=$(stat -f '%Su' $WOROOT/CONF/GRIDS2NODES)
    wogrp=$(stat -f '%Sg' $WOROOT/CONF/GRIDS2NODES)
fi

FPATH=$WOROOT/CONF/FORMS
LFPATH=$WOROOT/CONF/LEGACY_FORMS
LFDB=$WOROOT/DATA/BACKUP_LEGACY_FORMS
DATS=()

echo "Start legacy form migration..."
cmd "mkdir -p $LFPATH/FORMS $LFPATH/GRIDS2FORMS $LFDB"

# =============================================================================
# make a loop on all known legacy FORMs
#for form in EAUX RIVERS RAINWATER SOILSOLUTION GAZ EXTENSO FISSURO DISTANCE BOJAP
LEGACY_FORMS=("EAUX" "EAUX_OVSM" "RIVERS" "RAINWATER" "SOILSOLUTION" "GAZ" "EXTENSO" "FISSURO")
for form in "${LEGACY_FORMS[@]}"; do
    echo
    echo "--->Process form $form"
    # -----------------------------------------------------------------------------
    # test if a legacy form might exist...
    conf="$WOROOT/CONF/FORMS/$form/$form.conf"
    if [[ ! -e "$conf" ]]; then
        echo "---> No form $form"
        continue
    fi
    FDAT=$(grep ^FILE_NAME $conf | cut -d '|' -f 2)
    DAT="$WOROOT/DATA/DB/"$(grep ^FILE_NAME $conf | cut -d '|' -f 2)
    if [[ -z "$FDAT" || ! -e "$DAT" ]]; then
        echo "---> No legacy data found in $conf... nothing to do for $form."
        continue
    fi

    DATS+=($DAT)

    # move the legacy conf and data first
    echo "---> Backup legacy conf."
    cmd "mv -f $FPATH/$form $LFPATH/FORMS/"
    conf0="$LFPATH/FORMS/$form/$form.conf"

    readarray -t procs2forms < <(find $WOROOT/CONF/GRIDS2FORMS/PROC.*.$form -maxdepth 1 -type f)
    if [[ ${#procs2forms[@]} -eq 0 ]]; then
        echo "No PROCs associated with $form"
    fi

    # make a loop on all PROCs associated to this FORM
    for p in "${procs2forms[@]}"; do
        # -----------------------------------------------------------------------------
        # get the names of proc, form and nodes
        proc=$(echo $p | cut -d '.' -f 2)
        nodes=()
        echo
        echo "---> Migrating PROC '$proc' to GENFORM (Path: $p)"
        echo "FORM = $form"

        readarray -t procs2nodes < <(find $WOROOT/CONF/GRIDS2NODES/PROC.$proc* -maxdepth 1 -type f)
        if [[ ${#procs2nodes[@]} -eq 0 ]]; then
            echo "No NODEs associated to $form form!"
        else
            for n in "${procs2nodes[@]}"; do
                nodes+=($(echo $n | cut -d '.' -f 3))
            done

            echo -n " NODES ="
            printf " %s" ${nodes[@]}
        fi
        echo ""

        # -----------------------------------------------------------------------------
        # make the form conf
        dconf1="$WOROOT/CONF/FORMS/$proc"
        confp="$WOROOT/CONF/PROCS/$proc/$proc.conf"
        conf="$dconf1/$proc.conf"

        # database table (lowercase proc name)
        DBT=$(echo "$proc" | tr '[:upper:]' '[:lower:]')

        cmd "mkdir -p $dconf1"

        echo  "Creating/populating $DBT table with former $DAT..."

        # -- start SQL script
        echo "BEGIN TRANSACTION;" > $TMP
        echo "DROP TABLE if exists $DBT;" >> $TMP

        printf "CREATE TABLE IF NOT EXISTS geoloc (id INTEGER PRIMARY KEY, latitude REAL, northern_error REAL, longitude REAL, eastern_error REAL, elevation REAL, elevation_error REAL);\n" >> $TMP
        printf "CREATE TABLE IF NOT EXISTS udate (id INTEGER PRIMARY KEY, date TEXT, date_min TEXT, yce REAL, yce_min REAL);\n" >> $TMP
        printf "CREATE TABLE $DBT (id integer PRIMARY KEY AUTOINCREMENT, trash boolean DEFAULT FALSE, quality integer, node text NOT NULL" >> $TMP
        printf ", edate INTEGER, sdate INTEGER, operators text NOT NULL" >> $TMP
        printf ", comment text, tsupd text NOT NULL, userupd text NOT NULL" >> $TMP

        case "$form" in
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "EAUX")
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
                printf ", FOREIGN KEY (edate) REFERENCES udate(id), FOREIGN KEY (sdate) REFERENCES udate(id)" >> $TMP
                echo ");" >> $TMP
                tac $DAT | iconv -f ISO-8859-1 -t UTF-8 | gawk -F '|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\""; \
                    gsub(/"/,"\"\"", $ic); \
                    var = $ic ($ic != "" && $iv != "" ? " " : "") $iv; \
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var); \
                    if ($iv ~ /^\[.*\] /) { \
                        split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\"%s\",\""v[1]"\",\""v[2]"\"", var \
                    } else { printf ",\"!\",\"%s\",\"\",\"\"", var }; \
                    for (i=5;i<n+5;i++) printf ",\""$i"\""; \
                    print ");"
                    val = $2 ($3 == "" ? "" : " " $3)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET edate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);\n"} }' >> $TMP
                ;;
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "RAINWATER")
                NBI=13
                ICOM=20
                IVAL=21

                TEMPLATE="RAINWATER"

                # copy template files
                cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
                cmd "cp $RELBASE/CODE/tplates/FORM_$TEMPLATE*.conf $dconf1/"

                # ID|Date2|Time2|Site|Date1|Time1|Volume (ml)|Diameter (cm)|pH|Cond. (C)|Na (ppm)|K (ppm)|Mg (ppm)|Ca (pmm)|HCO3 (ppm)|Cl (ppm)|SO4 (ppm)|dD (?)|d18O (?)|Comments|Valid
                # 1 |2    |3    |4   |5    |6    |7          |8            |9 |10       |11      |12     |13      |14      |15        |16      |17       |18    |19      |20      |21
                for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
                printf ", FOREIGN KEY (edate) REFERENCES udate(id), FOREIGN KEY (sdate) REFERENCES udate(id)" >> $TMP
                echo ");" >> $TMP
                tac $DAT | iconv -f ISO-8859-1 -t UTF-8 | gawk -F '|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\""; \
                    gsub(/"/,"\"\"", $ic); \
                    var = $ic ($ic != "" && $iv != "" ? " " : "") $iv; \
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var); \
                    if ($iv ~ /^\[.*\] /) { \
                        split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\"%s\",\""v[1]"\",\""v[2]"\"", var \
                    } else { printf ",\"!\",\"%s\",\"\",\"\"", var }; \
                    for (i=7;i<n+7;i++) printf ",\""$i"\""; \
                    print ");"
                    val = $2 ($3 == "" ? "" : " " $3)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET edate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);\n"
                    val = $5 ($6 == "" ? "" : " " $6)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET sdate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);\n\n"}' >> $TMP
                ;;
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "SOILSOLUTION")
                NBI=14
                ICOM=21
                IVAL=22

                TEMPLATE="SOILSOLUTION"

                # copy template files
                cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
                cmd "cp $RELBASE/CODE/tplates/FORM_$TEMPLATE*.conf $dconf1/"

                # ID|Date2|Time2|Site|Date1|Time1|Depth (cm)|Level|pH|Cond. (S)|Na (ppm)|K (ppm)|Mg (ppm)|Ca (pmm)|HCO3 (ppm)|Cl (ppm)|NO3 (ppm)|SO4 (ppm)|SiO2 (ppm)|DOC (ppm)|Comments|Valid
                # 1 |2    |3    |4   |5    |6    |7         |8    |9 |10       |11      |12     |13      |14      |15        |16      |17       |18       |19        |20       |21      |22
                for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
                printf ", FOREIGN KEY (edate) REFERENCES udate(id), FOREIGN KEY (sdate) REFERENCES udate(id)" >> $TMP
                echo ");" >> $TMP
                tac $DAT | iconv -f ISO-8859-1 -t UTF-8 | gawk -F '|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\""; \
                    gsub(/"/,"\"\"", $ic); \
                    var = $ic ($ic != "" && $iv != "" ? " " : "") $iv; \
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var); \
                    if ($iv ~ /^\[.*\] /) { \
                        split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\"%s\",\""v[1]"\",\""v[2]"\"", var \
                    } else { printf ",\"!\",\"%s\",\"\",\"\"", var }; \
                    for (i=7;i<n+7;i++) printf ",\""$i"\""; \
                    print ");"
                    val = $2 ($3 == "" ? "" : " " $3)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET edate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);"
                    val = $5 ($6 == "" ? "" : " " $6)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET sdate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);"}' >> $TMP
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
                printf ", FOREIGN KEY (edate) REFERENCES udate(id), FOREIGN KEY (sdate) REFERENCES udate(id)" >> $TMP
                echo ");" >> $TMP
                tac $DAT | iconv -f ISO-8859-1 -t UTF-8 | gawk -F '|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\""; \
                    gsub(/"/,"\"\"", $ic); \
                    var = $ic ($ic != "" && $iv != "" ? " " : "") $iv; \
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var); \
                    if ($iv ~ /^\[.*\] /) { \
                        split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\"%s\",\""v[1]"\",\""v[2]"\"", var \
                    } else { printf ",\"!\",\"%s\",\"\",\"\"", var }; \
                    for (i=5;i<n+5;i++) printf ",\""$i"\""; \
                    print ");"
                    val = $2 ($3 == "" ? "" : " " $3)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET edate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);\n"} }' >> $TMP
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
                printf ", FOREIGN KEY (edate) REFERENCES udate(id), FOREIGN KEY (sdate) REFERENCES udate(id)" >> $TMP
                echo ");" >> $TMP
                tac $DAT | iconv -f ISO-8859-1 -t UTF-8 | gawk -F '|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\""; \
                    gsub(/"/,"\"\"", $ic); \
                    var = $ic ($ic != "" && $iv != "" ? " " : "") $iv; \
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var); \
                    if ($iv ~ /^\[.*\] /) { \
                        split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\"%s\",\""v[1]"\",\""v[2]"\"", var \
                    } else { printf ",\"!\",\"%s\",\"\",\"\"", var }; \
                    for (i=5;i<n+5;i++) printf ",\""$i"\""; \
                    print ");"
                    val = $2 ($3 == "" ? "" : " " $3)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET edate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);\n"} }' >> $TMP
                ;;
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
                printf ", FOREIGN KEY (edate) REFERENCES udate(id), FOREIGN KEY (sdate) REFERENCES udate(id)" >> $TMP
                echo ");" >> $TMP
                tac $DAT | iconv -f ISO-8859-1 -t UTF-8 | gawk -F '|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    gsub(/\+/, ",", $5);
                    printf "VALUES(\""bin"\",\"1\",\""$4"\",\""$5"\""; \
                    gsub(/"/,"\"\"", $ic); \
                    var = $ic ($ic != "" && $iv != "" ? " " : "") $iv; \
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var); \
                    if ($iv ~ /^\[.*\] /) { \
                        split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\"%s\",\""v[1]"\",\""v[2]"\"", var \
                    } else { printf ",\"%s\",\"\",\"\"", var }; \
                    for (i=6;i<10;i++) printf ",\""$i"\""; \
                    for (i=10;i<35;i+=3) {
                        j = i+1; k = i+2;
                        if ($i == "") { d = ""; } else { d = $i + $j; }
                        printf ",\""d"\",\""$k"\""; \
                    }
                    print ");"
                    val = $2 ($3 == "" ? "" : " " $3)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET edate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);\n"} }' >> $TMP
                ;;
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "FISSURO")
                NBI=40
                ICOM=46
                IVAL=47

                # uses French template
                TEMPLATE="FISSURO"

                # copy template files
                cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
                cmd "cp $RELBASE/CODE/tplates/FORM_$TEMPLATE*.conf $dconf1/"

                #ID|Date|Heure|Site|Opérateurs|Température|Météo|Instrument|Composante|P1|L1|V1|P2|L2|V2|P3|L3|V3|P4|L4|V4|P5|L5|V5|P6|L6|V6|P7|L7|V7|P8|L8|V8|P9|L9|V9|P10|L10|V10|P11|L11|V11|P12|L12|V12|Remarques|Validation
                #1 |2   |3    |4   |5         |6          |7    |8         |9         |10|11|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|28|29|30|31|32|33|34|35|36|37 |38 |39 |40 |41 |42 |43 |44 |45 |46       |47
                for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
                printf ", FOREIGN KEY (edate) REFERENCES udate(id), FOREIGN KEY (sdate) REFERENCES udate(id)" >> $TMP
                echo ");" >> $TMP
                tac $DAT | iconv -f ISO-8859-1 -t UTF-8 | gawk -F '|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    gsub(/\+/, ",", $5);
                    printf "VALUES(\""bin"\",\"1\",\""$4"\",\""$5"\""; \
                    gsub(/"/,"\"\"", $ic); \
                    var = $ic ($ic != "" && $iv != "" ? " " : "") $iv; \
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var); \
                    if ($iv ~ /^\[.*\] /) { \
                        split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\"%s\",\""v[1]"\",\""v[2]"\"", var \
                    } else { printf ",\"%s\",\"\",\"\"", var }; \
                    for (i=6;i<10;i++) printf ",\""$i"\""; \
                    for (i=10;i<35;i+=3) {
                        j = i+1; k = i+2;
                        d = $i + $j;
                        printf ",\""d"\",\""$k"\""; \
                    }
                    print ");"
                    val = $2 ($3 == "" ? "" : " " $3)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET edate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);\n"} }' >> $TMP
                ;;
            # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            "DISTANCE")
                NBI=27
                ICOM=32
                IVAL=33

                # uses French template
                TEMPLATE="DISTANCE"

                # copy template files
                cmd "cp $RELBASE/CODE/tplates/FORM.$TEMPLATE $conf"
                cmd "cp $RELBASE/CODE/tplates/FORM_$TEMPLATE*.conf $dconf1/"

                # Id|Date|Heure|Site|AEMD|Patm (mmHg)|Tair (C)|H.R. (%)|Nébulosité|Vitre|D0|d01|d02|d03|d04|d05|d06|d07|d08|d09|d10|d11|d12|d13|d14|d15|d16|d17|d18|d19|d20|Remarques|Valide
                # 1 |2   |3    |4   |5   |6          |7       |8       |9         |10   |11|12 |13 |14 |15 |16 |17 |18 |19 |20 |21 |22 |23 |24 |25 |26 |27 |28 |29 |30 |31 |32       |33
                for i in $(seq 1 $NBI); do printf ", input%02d text" $i >> $TMP; done
                printf ", FOREIGN KEY (edate) REFERENCES udate(id), FOREIGN KEY (sdate) REFERENCES udate(id)" >> $TMP
                echo ");" >> $TMP
                tac $DAT | iconv -f ISO-8859-1 -t UTF-8 | gawk -F '|' -v t="$DBT" -v n="$NBI" -v ic="$ICOM" -v iv="$IVAL" ' { if ($1 != "ID") { \
                    bin = ($1<0) ? 1:0; \
                    printf "INSERT INTO "t"(trash,quality,node,operators,comment,tsupd,userupd"; \
                    for (i=1;i<=n;i++) printf ",input%02d",i; \
                    printf ") ";\
                    printf "VALUES(\""bin"\",\"1\",\""$4"\""; \
                    gsub(/"/,"\"\"", $ic); \
                    var = $ic ($ic != "" && $iv != "" ? " " : "") $iv; \
                    gsub(/^[[:space:]]+|[[:space:]]+$/, "", var); \
                    if ($iv ~ /^\[.*\] /) { \
                        split($iv,vv,/\] \[/); split(vv[1],v," "); \
                        gsub(/\[/, "", v[1]); gsub(/\]/, "", v[2]); \
                        printf ",\""v[2]"\",\"%s\",\""v[1]"\",\""v[2]"\"", var \
                    } else { printf ",\"!\",\"%s\",\"\",\"\"", var }; \
                    for (i=5;i<n+5;i++) printf ",\""$i"\""; \
                    print ");"
                    val = $2 ($3 == "" ? "" : " " $3)
                    printf "INSERT INTO udate (date, date_min) VALUES (\x27%s\x27, \x27%s\x27);\n", val, val
                    printf "UPDATE "t" SET edate = last_insert_rowid() WHERE id = (SELECT id FROM "t" ORDER BY id DESC LIMIT 1);\n"} }' >> $TMP
                ;;
        esac

        # -- end of SQL script
        echo "COMMIT;" >> $TMP
        cmd "cat $TMP | sqlite3 $DBF && rm -f $TMP"

        if [[ -f "$conf" && -f "$conf0" ]]; then
            # -----------------------------------------------------------------------------
            # copy some variable values from former FORM and PROC conf
            v=$(grep ^TITLE\| "$conf0" | sed -e 's/&/\\&/g' | iconv -f UTF-8 -t ISO-8859-1)
            cmd "LC_ALL=C sed -i -e 's/^NAME|.*$/$v/g;s/^TITLE/NAME/g' $conf"
            for key in BANG DEFAULT_DAYS; do
                okey=$(grep ^$key\| "$conf0")
                if [[ ! -z "$okey" ]]; then
                    cmd "LC_ALL=C sed -i -e 's/^$key|.*$/$okey/g' $conf"
                fi
            done
        fi

        if [[ -f "$conf" && -f "$confp" ]]; then
            for key in TZ OWNCODE TYPE URL COPYRIGHT NODE_NAME NODE_SIZE NODE_MARKER NODE_RGB DEM_FILE DEM_TYPE DEM_COPYRIGHT; do
                v=$(grep '^$key|' "$confp")
                if [[ ! -z $v ]]; then
                    cmd "LC_ALL=C sed -i -e 's/^$key|.*$/$v/g' $conf"
                fi
            done
        fi

        if [[ -f "$confp" ]]; then
            # -----------------------------------------------------------------------------
            # add default data format to the PROC conf
            cmd "LC_ALL=C sed -i -e 's/^RAWDATA|.*//g;s/^RAWFORMAT|.*//g' $confp" # removes any RAWFORMAT/RAWDATA
            cmd "echo '################################################################################' >> $confp"
            cmd "echo '# Migrate legacy form $form to new FORM.$proc on $today' >> $confp"
            cmd "echo 'RAWFORMAT|genform' >> $confp"
            cmd "echo 'RAWDATA|$proc' >> $confp"
            cmd "echo '################################################################################' >> $confp"
        fi

        if [[ ${#procs2nodes[@]} -ne 0 ]]; then
            # -----------------------------------------------------------------------------
            # make the new links form2nodes
            for n in ${nodes[@]}; do
                cmd "ln -sf $WOROOT/DATA/NODES/$n $WOROOT/CONF/GRIDS2NODES/FORM.$proc.$n"
            done

            cmd "chown $wousr:$wogrp $WOROOT/CONF/GRIDS2NODES/FORM.$proc.*"
        fi

        # -----------------------------------------------------------------------------
        # add form in grids2domains (WEBOBSDOMAINS.db)
        if [[ -f "$DBD" ]]; then
            echo "Update database: ${DBD}"
            sqlite3 "$DBD" "INSERT INTO grids2domains (TYPE, NAME, DCODE) SELECT 'FORM', NAME, DCODE FROM grids2domains WHERE TYPE = 'PROC' AND NAME = '$proc';"
        fi

        # -----------------------------------------------------------------------------
        # finally moves legacy conf
        cmd "mv $WOROOT/CONF/GRIDS2FORMS/PROC.$proc.$form $LFPATH/GRIDS2FORMS/"

        cmd "chown -R $wousr:$wogrp $dconf1"

        echo "Done."
    done
done

# Moves data from legacy forms outside the previous loop in case of shared DAT files
echo
echo "Backup legacy forms:"
for i in "${!DATS[@]}"; do
    if [[ -f "${DATS[i]}" ]]; then
        cmd "mv ${DATS[i]} $LFDB/"
    fi
done

exit 1

