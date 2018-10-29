#!/bin/bash

SC3=/srv/sismo/seiscomp3/events
HYPO=/srv/ipgp/acqui/Sismologie/Hypocentres/hypoovsg.trie.txt
FROM=/srv/ipgp/acqui/Sismologie/B3
TO=/opt/webobs/OUTG/PROC.B3OVSG/events
#SC3=~/WEBOBS/wo/sefran/sc3_events
#HYPO=~/WEBOBS/data-test/Sismologie/Hypocentres/hypoovsg.trie.txt
#FROM=~/WEBOBS/data-test/Sismologie/B3
#TO=~/WEBOBS/wo/OUTG/PROC.B3OVSG/events

for year in $(ls $FROM/traites/); do
	for month in $(seq -f %02g 1 12); do
		for f in $(ls $FROM/traites/$year/$month/*.txt); do
			FILE=$(basename $f .txt)
			DATE=$(echo $FILE | cut -d 'T' -f 1)
			YEAR=$(echo $FILE | cut -c 1-4)
			MONTH=$(echo $FILE | cut -c 5-6)
			DAY=$(echo $FILE | cut -c 7-8)
			HOUR=$(echo $FILE | cut -c 10-11)
			MIN=$(echo $FILE | cut -c 12-13)
			SEC=$(echo $FILE | awk '{if (substr($0,14,2)=="60") print "59"; else print substr($0,14,2);}')
			#ORIGIN=$(printf "%s %2d%2d %2d" $DATE $HOUR $MIN $SEC)
			ORIGIN1=$(date -d "$(echo "$YEAR $MONTH $DAY $HOUR $MIN $SEC" | awk '{printf("%s-%s-%s %02d:%02d:%02d",$1,$2,$3,$4,$5,$6)}') 1 second ago" +"%Y%m%d %H %M %S" | awk '{printf("%s %2d%2d %2d",$1,$2,$3,$4)}')
			ORIGIN10=$(date -d "$(echo "$YEAR $MONTH $DAY $HOUR $MIN $SEC" | awk '{printf("%s-%s-%s %02d:%02d:%02d",$1,$2,$3,$4,$5,$6)}') 1 second ago" +"%Y%m%d %H%M %S")
			ORIGIN=$(echo "$DATE $HOUR $MIN $SEC" | awk '{printf("%s %2d%2d %2d",$1,$2,$3,$4)}')
			ORIGIN0=$(echo "$DATE $HOUR$MIN $SEC")
			ID=$(grep -E "$ORIGIN|$ORIGIN0|$ORIGIN1|$ORIGIN10" $HYPO | awk '{print $NF}' | head -n 1 | cut -c -15 | cut -d '.' -f 1)
			if [ -z $ID ]; then
				echo "** no ID found for $f..."
			else
				echo "$ID: $f **"
				DIR=$TO/$YEAR/$MONTH/$DAY/$ID
				mkdir -p $DIR
				cp -a $f $DIR/
				if [ -f $FROM/ressentis/$year/$month/$FILE.png ]; then
					cp -a $FROM/ressentis/$year/$month/$FILE.png $DIR/
				fi
				if [ -f $FROM/ressentis/$year/$month/$FILE.pdf ]; then
					cp -a $FROM/ressentis/$year/$month/$FILE.pdf $DIR/
					ln -s $FILE.pdf $DIR/b3.pdf
				elif [ -f $FROM/ressentis/$year/$month/$FILE.png ]; then
					ln -s $FILE.png $DIR/b3.png
				fi
				if [ -f $FROM/ressentis/$year/$month/$FILE.jpg ]; then
					cp -a $FROM/ressentis/$year/$month/$FILE.jpg $DIR/
					ln -s $FILE.jpg $DIR/b3.jpg
				fi
				if [ -f $FROM/gse/$year/$month/${FILE}_gse.txt ]; then
					cp -a $FROM/gse/$year/$month/${FILE}_gse.txt $DIR/
					ln -s ${FILE}_gse.txt $DIR/b3.gse
				fi
			fi
		done
	done
done

for sc3 in $(find $SC3 -name *.summary); do
	ID=$(basename $sc3 .summary)
	ORIGIN=$(tail -n1 $sc3 | grep -E "M$" | cut -d '|' -f 1,2)
	if [[ ! -z $ORIGIN ]]; then
		DATE=$(echo $ORIGIN | cut -d '|' -f 1)
		DELAY=$(echo $ORIGIN | awk -F "|" '{printf("%1.0f",$2*60)}')
		ORIGIN=$(date -d "$DATE $DELAY seconds ago" +"%Y%m%dT%H%M%S_b3.txt")
		ORIGIN1=$(date -d "$DATE $DELAY seconds ago 1 second" +"%Y%m%dT%H%M%S_b3.txt")
		ORIGIN2=$(date -d "$DATE $DELAY seconds ago 1 second ago" +"%Y%m%dT%H%M%S_b3.txt")
		if [ -z $(find $TO -name '*_b3.txt' | grep -E "$ORIGIN|$ORIGIN1|$ORIGIN2" | tail -n1) ]; then
			echo "** no B3 found for $ORIGIN..."
		else
			B3=$(dirname $(find $TO -name '*_b3.txt' | grep -E "$ORIGIN|$ORIGIN1|$ORIGIN2" | tail -n1))
			DIR=$(dirname $B3)
			IDB3=$(basename $B3)
			LISTEB3=$(ls $DIR/$IDB3/*_b3.txt)
			for f in $LISTEB3; do
				FILEB3=$(basename $f .txt)
				echo "$ID: $DIR $IDB3 $FILEB3"
				if [[ ! -d $DIR/$ID ]]; then
					mkdir -p $DIR/$ID
					ln -s ../$IDB3/${FILEB3}.txt $DIR/$ID/${FILEB3}.txt
					if [ -f $DIR/$IDB3/${FILEB3}.pdf ]; then
						ln -s ../$IDB3/${FILEB3}.pdf $DIR/$ID/${FILEB3}.pdf
						ln -s ${FILEB3}.pdf $DIR/$ID/b3.pdf
					elif [ -f $DIR/$IDB3/${FILEB3}.png ]; then
						ln -s ../$IDB3/${FILEB3}.png $DIR/$ID/${FILEB3}.png
						ln -s ${FILEB3}.png $DIR/$ID/b3.png
					fi
					if [ -f $DIR/$IDB3/${FILEB3}.jpg ]; then
						ln -s ../$IDB3/${FILEB3}.jpg $DIR/$ID/${FILEB3}.jpg
						ln -s ${FILEB3}.jpg $DIR/$ID/b3.jpg
					fi
					if [ -f $DIR/$IDB3/${FILEB3}_gse.txt ]; then
						ln -s ../$IDB3/${FILEB3}_gse.txt $DIR/$ID/${FILEB3}_gse.txt
						ln -s ${FILEB3}_gse.txt $DIR/$ID/b3.gse
					fi
				else
					ln -s ../$IDB3/${FILEB3}.txt $DIR/$ID/${FILEB3}.txt
					if [ -f $DIR/$IDB3/${FILEB3}.pdf ]; then
						ln -s ../$IDB3/${FILEB3}.pdf $DIR/$ID/${FILEB3}.pdf
					elif [ -f $DIR/$IDB3/${FILEB3}.png ]; then
						ln -s ../$IDB3/${FILEB3}.png $DIR/$ID/${FILEB3}.png
					fi
					if [ -f $DIR/$IDB3/${FILEB3}.jpg ]; then
						ln -s ../$IDB3/${FILEB3}.jpg $DIR/$ID/${FILEB3}.jpg
					fi
					if [ -f $DIR/$IDB3/${FILEB3}_gse.txt ]; then
						ln -s ../$IDB3/${FILEB3}_gse.txt $DIR/$ID/${FILEB3}_gse.txt
					fi
				fi
			done
		fi
	fi
done

