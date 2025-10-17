#!/bin/bash

# This script modifies the name of a WebObs GRID (PROC or VIEW)

#******************* Changes for files and directories *******************#

# Rename filenames:
# CONF/PROCS/PROCNAME/PROCNAME.conf
# DATA/GRIDS/PROC/PROCNAME/*/PROCNAME_*.txt
# DATA/NODES/*/PROC.PROCNAME.*.clb
# DATA/WEB/*/PROC.PROCNAME_*.txt
# OUTG/PROC.PROCNAME/*/PROC.PROCNAME*

# Rename symbolic links:
# CONF/GRIDS2NODES/PROC.PROCNAME.*
# CONF/GRIDS2FORMS/PROC.PROCNAME.*

# Rename directories:
# CONF/PROCS/PROCNAME
# OUTG/PROC.PROCNAME
# DATA/GRIDS/PROC/PROCNAME

# Text replacements:
# PROCNAME.conf in CONF/PROCS
# *.clb files in DATA/NODES
# *.cnf files in DATA/NODES
#.*.txt files in DATA/NODES
# *.txt files in DATA/WEB
# menunav.html
# theia.rc


#************************* Database changes *************************#

#-------------------------------------------------------------------------------------
# database      | table name            | field        | pattern / example
#-------------------------------------------------------------------------------------
# Gazette       | gazette               | PLACE        | PROC.METEODEUX.
# NODESSTATUS   | status                | NODE         | PROC.RIVERWATER
# WEBOBSDOMAINS | grids2domains         | NAME         | RIVERWATER
# WEBOBSJOBS    | jobs                  | RES          | RIVERWATER
# WEBOBSJOBS    | jobs                  | XEQ2         | RIVERWATER
# WEBOBSJOBS    | runs                  | CMD          | RIVERWATER (between spaces)
# WEBOBSMETA    | contacts              | RELATED_ID   | _DAT_METEODEUX.
# WEBOBSMETA    | datasets              | IDENTIFIER   | _DAT_METEODEUX.
# WEBOBSMETA    | grids2producers       | NAME         | RIVERWATER
# WEBOBSMETA    | observations          | IDENTIFIER   | _OBS_METEODEUX.
# WEBOBSMETA    | observations          | STATIONNAME  | METEODEUX.
# WEBOBSMETA    | observations          | DATASET      | _DAT_METEODEUX.
# WEBOBSMETA    | observations          | DATAFILENAME | _OBS_METEODEUX.
# WEBOBSMETA    | sampling_features     | IDENTIFIER   | METEODEUX.
# WEBOBSUSERS   | auth(proc|view|form)s | RESOURCE     | RIVERWATER


ROOT_SITE="/opt/webobs"
CONF_DIR="$ROOT_SITE/CONF"
DATA_DIR="$ROOT_SITE/DATA"
OUTG_DIR="$ROOT_SITE/OUTG"

# Services
WOSCHEDULER="woscheduler"
WOPOSTBOARD="wopostboard"
APACHE="apache2"

# Parse args
OUTG_FILES="off"
BACKUP="off"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --outg-files)
            OUTG_FILES="on"
            shift
            ;;
        --ask-backup)
            BACKUP="on"
            shift
            ;;
        *)
            echo "Option invalide."
            exit 1
            ;;
    esac
done

check_oldname() {
    # Exit if the grid doesn't exist.
    if [[ ! -d "$CONF_DIR/${GRID}S/$1" ]]; then
        echo "The ${GRID,,} "$1" was not found!"
        stop
    fi

    # Exit if the grid name is DOWNFLOWGO.
    if [[ "$1" == "DOWNFLOWGO" ]]; then
        echo "DOWNFLOWGO ${GRID,,} name cannot be modified!"
        stop
    fi

    is_valid_name $1
}

check_newname() {
    # Exit if the grid doesn't exist.
    if [[ -d "$CONF_DIR/${GRID}S/$1" ]]; then
        echo "The ${GRID,,} "$1" already exist!"
        stop
    fi

    # Exit if the grid name is DOWNFLOWGO.
    if [[ "$1" == "DOWNFLOWGO" ]]; then
        echo "DOWNFLOWGO is a reserved ${GRID,,} name!"
        stop
    fi

    is_valid_name $1
}

is_valid_name() {
    # Check if there is at least one letter
    if [[ ! "$1" =~ [a-zA-Z] ]]; then
        echo "The name must contain at least one letter."
        stop
    fi

    # Check if the name contains only letters, digits, or underscores
    if [[ ! "$1" =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo "The name must contain only letters, digits, or underscores."
        stop
    fi
}

# Exit function
stop() {
    echo "Operation canceled!"
    exit 1
}

# Function to rename directories and files
rename_path() {
    if [[ "$#" -ne 3 ]]; then
        echo "Error: This function ($FUNCNAME) requires exactly 3 arguments." >&2
        stop
    fi

    local path="$1"
    local pattern="$2"
    local replace="$3"

    newpath=$(perl -pe "s/$pattern/$replace/g" <<< "$path")
    if [[ -e "$path" ]] && [[ "$path" != "$newpath" ]]; then
        echo "Renaming $path to $newpath"
        mv "$path" "$newpath"
    fi
}

# Function to rename symbolic links
rename_links() {
    if [[ "$#" -ne 3 ]]; then
        echo "Error: This function ($FUNCNAME) requires exactly 3 arguments." >&2
        stop
    fi

    local directory="$1"
    local pattern="$2"
    local replace="$3"

    if [[ -d "$directory" ]]; then
        while read -r path; do
            if [[ -L "$path" ]]; then
                newlink=$(perl -pe "s/$pattern/$replace/g" <<< "$path")
                target=$(readlink "$path")
                ln -sf "$target" "$newlink"
                if [[ $? -eq 0 ]]; then
                    echo "Renaming link $path to $newlink"
                    rm "$path"
                fi
            fi
        done < <(find "$directory" -type l -name "${GRID}.${OLD}.*")
    fi
}

# Function to replace grid name in files
replace_in_file() {
    if [[ "$#" -ne 3 ]]; then
        echo "Error: This function ($FUNCNAME) requires exactly 3 arguments." >&2
        stop
    fi

    local path="$1"
    local pattern="$2"
    local replace="$3"

    if grep -q "$pattern" "$path"; then
        echo "Replacing '$pattern' with '$replace' in $path"
        perl -i -pe "s/(?<=[^a-zA-Z0-9]|^)$pattern(?=[^a-zA-Z0-9_]|$)/$replace/g" "$path"
    fi
}

# Is the script is run with Bash?
if [[ -z "$BASH_VERSION" ]]; then
    echo "Error: This script must be run with Bash."
    echo "Please use: bash $0"
    stop
fi

# Is perl installed?
if ! [[ -x $(command -v perl) ]]; then
    echo "Perl must be installed and marked as executable before running this script!"
    stop
fi

# Is the root directory exists?
if [[ ! -d "$ROOT_SITE" ]]; then
    echo "The directory $ROOT_SITE does not exist."
    stop
fi

# Check write permissions
directories=(
    "$CONF_DIR"
    "$DATA_DIR"
    "$OUTG_DIR"
)

for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]] && [[ ! -w "$dir" ]]; then
        echo "Error: You do not have permission to write to the $dir directory."
        stop
    fi
done

echo
echo "This script allows you to change a webobs GRID name (PROC, VIEW or FORM)."
echo

#-------------------- Check services status --------------------#
if systemctl is-active --quiet $APACHE; then
    echo "You need to stop the $APACHE service."
    stop
elif systemctl is-active --quiet $WOPOSTBOARD; then
    echo "You need to stop the $WOPOSTBOARD service."
    stop
elif systemctl is-active --quiet $WOSCHEDULER; then
    echo "You need to stop the $WOSCHEDULER service."
    stop
fi

#-------------------- User choice --------------------#

while true; do
    echo "What would you like to rename?"
    echo "1. A PROC"
    echo "2. A VIEW"
    echo "3. A FORM"
    echo "4. Quit"

    read -p "Please choose an option (1, 2, 3, or 4): " choice

    case $choice in
        1)
            echo "You have chosen to rename a PROC."
            GRID="PROC"
            ;;
        2)
            echo "You have chosen to rename a VIEW."
            GRID="VIEW"
            ;;
        3)
            echo "You have chosen to rename a FORM."
            GRID="FORM"
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose 1, 2, 3, or 4."
            ;;
    esac

    echo
    if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "3" || "$choice" == "4" ]]; then
        break
    fi
done

#-------------------- Start of renaming --------------------#

# Ask the user for grid name to modify
read -p "Enter the ${GRID,,} name to modify: " OLD
check_oldname "$OLD"

# Ask the user for the new name
read -p "Enter the new ${GRID,,} name: " NEW
check_newname "$NEW"

# Exit if nothing to change
if [[ "$OLD" = "$NEW" ]]; then
    echo "Nothing to do: the old and new names are identical."
    stop
fi

# Backups
if [[ "$BACKUP" = "on" ]]; then
    read -p "Backup CONF and DATA directories? This may take some time. [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        timestamp=$(date +'%Y%m%dT%H%M%S')
        sudo tar -cpf "$ROOT_SITE/CONF_$timestamp.tar" -C "$ROOT_SITE" "./CONF"
        sudo tar -cpf "$ROOT_SITE/DATA_$timestamp.tar" -C "$ROOT_SITE" "./DATA"
    fi
fi

#-------------------- File or directory renaming --------------------#

PATTERN1="(${GRID}\.)${OLD}(\.)"
PATTERN2="(${GRID}\.)${OLD}(_[a-z]+\.)"
PATTERN3="([^a-zA-Z0-9_]|^)${OLD}([^a-zA-Z0-9]|$)"

# Rename files in $DATA_DIR/NODES
while read -r path; do
    rename_path "$path" "$PATTERN1" "\${1}${NEW}\${2}"
done < <(find "$DATA_DIR/NODES" -type f -name "${GRID}.${OLD}.*.clb")

# Rename files in $DATA_DIR/WEB
while read -r path; do
    rename_path "$path" "$PATTERN2" "\${1}${NEW}\${2}"
done < <(find "$DATA_DIR/WEB" -type f -name "${GRID}.${OLD}_*.txt")

# Rename proc OUTG directory and files
if [[ -d "$OUTG_DIR/${GRID}.$OLD" ]]; then
    mv "$OUTG_DIR/${GRID}.$OLD" "$OUTG_DIR/${GRID}.$NEW"
    while read -r path; do
        rename_path "$path" "$PATTERN2" "\${1}${NEW}\${2}"
    done < <(find "$OUTG_DIR/${GRID}.$NEW" -type f -name "${GRID}.${OLD}*")
fi

# Rename proc GRIDS directory and files
if [[ -d "$DATA_DIR/GRIDS/${GRID}/$OLD" ]]; then
    mv "$DATA_DIR/GRIDS/${GRID}/$OLD" "$DATA_DIR/GRIDS/${GRID}/$NEW"
    while read -r path; do
        rename_path "$path" "$PATTERN3" "\${1}${NEW}\${2}"
    done < <(find "$DATA_DIR/GRIDS/${GRID}/$NEW" -type f -name "${OLD}_*.txt")
fi

# Rename grid CONF directory and config file
if [[ -f "$CONF_DIR/${GRID}S/${OLD}/${OLD}.conf" ]]; then
    mv "$CONF_DIR/${GRID}S/${OLD}/${OLD}.conf" "$CONF_DIR/${GRID}S/${OLD}/${NEW}.conf"
    echo "Renaming $CONF_DIR/${GRID}S/${OLD}/${OLD}.conf to $CONF_DIR/${GRID}S/${NEW}/${NEW}.conf"
fi

if [[ -d "$CONF_DIR/${GRID}S/${OLD}" ]]; then
    mv "$CONF_DIR/${GRID}S/$OLD" "$CONF_DIR/${GRID}S/$NEW"
    echo "Renaming $CONF_DIR/${GRID}S/${OLD}/ to $CONF_DIR/${GRID}S/${NEW}/"
fi

# Rename form document directory
if [[ -d "$DATA_DIR/FORMDOCS/${OLD}" ]]; then
    mv "$DATA_DIR/FORMDOCS/$OLD" "$DATA_DIR/FORMDOCS/$NEW"
    echo "Renaming $DATA_DIR/FORMDOCS/$OLD/ to $DATA_DIR/FORMDOCS/$NEW/"
fi

# Rename symbolic links
rename_links "$CONF_DIR/GRIDS2NODES" "$PATTERN1" "\${1}${NEW}\${2}"
rename_links "$CONF_DIR/GRIDS2FORMS" "$PATTERN1" "\${1}${NEW}\${2}"

#-------------------- Text replacements --------------------#

# Text replacements in .clb files
while read -r path; do
    replace_in_file "$path" "${GRID}.$OLD" "${GRID}.$NEW"
done < <(find "$DATA_DIR/NODES" -type f -name "*.clb")

# Text replacements in .cnf files
while read -r path; do
    replace_in_file "$path" "${GRID}.$OLD" "${GRID}.$NEW"
done < <(find "$DATA_DIR/NODES" -type f -name "*.cnf")

# Text replacements in .txt files in DATA/NODES
while read -r path; do
    replace_in_file "$path" "${GRID}.$OLD" "${GRID}.$NEW"
done < <(find "$DATA_DIR/NODES" -type f -name "*.txt")

# Text replacements in .txt files in DATA/WEB
while read -r path; do
    replace_in_file "$path" "$OLD" "$NEW"
done < <(find "$DATA_DIR/WEB" -type f -name "${GRID}.${OLD}_*.txt")

# Text replacements in menunav.html
while read -r path; do
    replace_in_file "$path" "$OLD" "$NEW"
done < <(find "$CONF_DIR" -type f -name "menunav.html")

# Text replacements in theia.rc
while read -r path; do
    replace_in_file "$path" "DAT_$OLD" "DAT_$NEW"
    replace_in_file "$path" "OBS_$OLD" "OBS_$NEW"
done < <(find "$CONF_DIR" -type f -name "theia.rc")

# Text replacements in the grid conf file
while read -r path; do
    replace_in_file "$path" "$OLD" "$NEW"
done < <(find "$CONF_DIR/${GRID}S/$NEW" -type f -name "${NEW}.conf")

# Text replacements in files in OUTG/${GRID}.$OLD
if [[ "$OUTG_FILES" = "on" ]]; then
    while read -r path; do
        replace_in_file "$path" "${GRID}.$OLD" "${GRID}.$NEW"
        replace_in_file "$path" "${GRID}.${OLD}_map" "${GRID}.${NEW}_map"
    done < <(find "$OUTG_DIR/${GRID}.$NEW" -type f -name "*.*")
fi

#-------------------- Gazette.db --------------------#
DB_FILE="$DATA_DIR/DB/Gazette.db"

if [[ -f "$DB_FILE" ]] && grep -q "$OLD" "$DB_FILE"; then
    echo "Update gazette: ${DB_FILE}"
    sqlite3 "$DB_FILE" "
    UPDATE gazette SET
        PLACE = REPLACE(PLACE, '${GRID}.${OLD}.', '${GRID}.${NEW}.')
    WHERE
        PLACE GLOB '${GRID}.${OLD}.*';
    "
fi

#-------------------- NODESSTATUS.db --------------------#
DB_FILE="$DATA_DIR/DB/NODESSTATUS.db"

if [[ -f "$DB_FILE" ]] && grep -q "$OLD" "$DB_FILE"; then
    echo "Update database: ${DB_FILE}"
    sqlite3 "$DB_FILE" "
    UPDATE status SET
        NODE = REPLACE(NODE, '${GRID}.${OLD}.', '${GRID}.${NEW}.')
    WHERE
        NODE GLOB '${GRID}.${OLD}.*';
    "
fi

#-------------------- WEBOBSDOMAINS.db --------------------#
DB_FILE="$CONF_DIR/WEBOBSDOMAINS.db"

if [[ -f "$DB_FILE" ]] && grep -q "$OLD" "$DB_FILE"; then
    echo "Update database: ${DB_FILE}"
    sqlite3 "$DB_FILE" "
    UPDATE grids2domains SET
        NAME = REPLACE(NAME, '$OLD', '$NEW')
    WHERE
        NAME = '$OLD' AND TYPE = '$GRID';
    "
fi

#-------------------- WEBOBSFORMS.db --------------------#
DB_FILE="$DATA_DIR/DB/WEBOBSFORMS.db"

if [[ -f "$DB_FILE" ]]; then
    EXISTS=$(sqlite3 "$DB_FILE" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='${OLD,,}';")
    if [ "$EXISTS" -gt 0 ]; then
        echo "Rename table ${OLD,,} to ${NEW,,} in ${DB_FILE} database."
        sqlite3 "$DB_FILE" "
        ALTER TABLE '${OLD,,}' RENAME TO '${NEW,,}';
        "
    fi
fi

#-------------------- WEBOBSJOBS.db --------------------#
DB_FILE="$CONF_DIR/WEBOBSJOBS.db"

if [[ -f "$DB_FILE" ]] && grep -q "$OLD" "$DB_FILE"; then
    echo "Update database: ${DB_FILE}"
    sqlite3 "$DB_FILE" "
    UPDATE jobs SET
        RES = REPLACE(RES, '$OLD', '$NEW'),
        XEQ2 = REPLACE(XEQ2, '$OLD', '$NEW')
    WHERE
        RES = '$OLD' OR
        XEQ2 = '$OLD';
    "

    sqlite3 "$DB_FILE" "
    UPDATE runs SET
        CMD = REPLACE(CMD, '$OLD', '$NEW')
    WHERE
        CMD GLOB '* ${OLD} *';
    "
fi

#-------------------- WEBOBSMETA.db --------------------#
DB_FILE="$CONF_DIR/WEBOBSMETA.db"

if [[ -f "$DB_FILE" ]] && grep -q "$OLD" "$DB_FILE"; then
    sqlite3 "$DB_FILE" "
    UPDATE contacts SET
        RELATED_ID = REPLACE(RELATED_ID, '_DAT_${OLD}.', '_DAT_${NEW}.')
    WHERE
        RELATED_ID GLOB '*_DAT_${OLD}.*';
    "

    echo "Update database: ${DB_FILE}"
    sqlite3 "$DB_FILE" "
    UPDATE datasets SET
        IDENTIFIER = REPLACE(IDENTIFIER, '_DAT_${OLD}.', '_DAT_${NEW}.')
    WHERE
        IDENTIFIER GLOB '*_DAT_${OLD}.*';
    "

    sqlite3 "$DB_FILE" "
    UPDATE grids2producers SET
        NAME = REPLACE(NAME, '$OLD', '$NEW')
    WHERE
        NAME = '$OLD' AND TYPE = '$GRID';
    "

    sqlite3 "$DB_FILE" "
    UPDATE OR IGNORE observations SET
        IDENTIFIER = REPLACE(IDENTIFIER, '_OBS_${OLD}.', '_OBS_${NEW}.'),
        STATIONNAME = REPLACE(STATIONNAME, '${OLD}.', '${NEW}.'),
        DATASET = REPLACE(DATASET, '_DAT_${OLD}.', '_DAT_${NEW}.'),
        DATAFILENAME = REPLACE(DATAFILENAME, '_OBS_${OLD}.', '_OBS_${NEW}.')
    WHERE
        IDENTIFIER GLOB '*_OBS_${OLD}.*' OR
        STATIONNAME GLOB '${OLD}.*' OR
        DATASET GLOB '*_DAT_${OLD}.*' OR
        DATAFILENAME GLOB '*_OBS_${OLD}.*';
    "

    sqlite3 "$DB_FILE" "
    UPDATE sampling_features SET
        IDENTIFIER = REPLACE(IDENTIFIER, '${OLD}.', '${NEW}.')
    WHERE
        IDENTIFIER GLOB '${OLD}.*';
    "
fi

#-------------------- WEBOBSUSERS.db --------------------#
DB_FILE="$CONF_DIR/WEBOBSUSERS.db"

if [[ -f "$DB_FILE" ]] && grep -q "$OLD" "$DB_FILE"; then
    echo "Update database: ${DB_FILE}"
    sqlite3 "$DB_FILE" "
    UPDATE auth${GRID,,}s SET
        RESOURCE = REPLACE(RESOURCE, '$OLD', '$NEW')
    WHERE
        RESOURCE = '$OLD';
    "
fi

echo
echo "Renaming ${GRID,,} $OLD to $NEW completed."
echo
