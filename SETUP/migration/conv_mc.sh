#!/bin/bash

BASE_DIR="/ipgp/continu/sismo/sefran3"

# retourne 20131201_072400.mq0
function get_files() {
 awk 'BEGIN { FS="|" } $0 !~ /^$/ { print $13 }' $1
}

function get_mq {
	local filename="$1"
	echo "${filename:0:4}/${filename:2:4}/${filename%.mq0}_a.mq0"
}

function grep_event() {
	local origin="$1"
	local xml_file=$(grep -slr "$origin" $BASE_DIR/sc3_events/{2012,2013}) || return
	sed -r "s|$BASE_DIR/sc3_events/(.*)/[^/]*\.xml|\1|" <<< "$xml_file"
}

function get_eventID() {
	local ev="$1"

	# Construction du nom du fichier dans les archives CourtePeriode
	filename=$(get_mq $ev)

	# Récupération de l'id de la dernière locatisation (Origin#...) dans
	# les fichiers de CourtePeriode du style
	# $BASE_DIR/mc3/fromold/origin/CourtePeriode/2013/1304/20130419_042200_a.mq0
	dirname=$(dirname $filename)
	#echo filename=$filename >&2
	if [[ ! -f "$BASE_DIR/mc3/fromold/origin/CourtePeriode/$filename" ]]; then
          echo "ERROR: mq file $ev: $BASE_DIR/mc3/fromold/origin/CourtePeriode/$filename: not found" >&2
	  return 1
	fi

	# Lecture de la dernière origine dans le fichier
	origin=$(tail -n 1 $BASE_DIR/mc3/fromold/origin/CourtePeriode/$filename)
	#echo origin=$origin >&2
	[[ -z "$origin" ]] && {
	  echo "ERROR: Origin not found in $BASE_DIR/mc3/fromold/origin/CourtePeriode/$filename" >&2
	  return 1
	}

	# Récupération et retour de l'eventID dans les fichiers xml dump de seiscomp
	#awk -v orig="$origin" '$2 == orig { print $1 }' $ORIGINS_DB
	local eventid=$(grep_event "$origin")
	[[ -z "$eventid" ]] && { echo "ERROR: $origin: eventID not found" >&2; return 1; }

 	echo "$eventid"	
	return 0
}

declare -i i=0
#for f in $(ls $BASE_DIR/mc3/fromold/webobsv2-arc/{2012,2013}/files/MC_*.txt)
for f in $(ls $BASE_DIR/mc3/fromold/webobsv2-arc/2013/files/MC_*.txt)
do
  output_file=$(sed "s|$BASE_DIR/mc3/fromold/webobsv2-arc|$BASE_DIR/mc3/fromold/webobsv2|" <<< "$f")
  mkdir -pv $(dirname $output_file) >&2
  #echo "$f -> $output_file" >&2
  #continue
  # Parcours de chaque ligne du fichier
  while read line
  do
	i+=1
	[[ -z "$line" ]] && continue;

	# Lecture de la colonne 13
	ev=$(awk 'BEGIN { FS="|" } { print $13 }' <<< "$line")
	if [[ -z "$ev" ]]; then
	  echo "$line"
	  echo "ERROR: no mq file in $f line $i" >&2
	  continue
	fi

	# Récupération de l'eventID dans le fichier mq0 du style
	# $BASE_DIR/mc3/fromold/origin/CourtePeriode/2013/1304/20130419_042200_a.mq0
	eid=$(get_eventID $ev)
	if [[ -z "$eid" ]]; then
	  echo "$line"
	  continue
	fi

	# Regénération de la ligne du fichier MC avec YYYY/MM/DD/<eventId> dans le champ 14
	# et modification du champ 13 en SEFRAN3_OVSM
	echo "writing eventID: $eid" >&2
	awk -v field="$eid" 'BEGIN { FS=OFS="|"; } { $13="SEFRAN3_OVSM"; $14=field; print }' <<< $line 
  done < $f > $output_file
done

