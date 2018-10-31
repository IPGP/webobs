#!/bin/bash

FROM=/ipgp/continu/sismo/sefran3/mc3/fromold/modif
DEST=/ipgp/continu/sismo/sefran3/mc3/fromold/webobsv2

for YEAR in {1600..2013}
do
        for MONTH in {01..12}
        do
                YM=${YEAR}${MONTH}
		YYMM=${YEAR:2:2}${MONTH}
                FILES="${FROM}/files/MC${YM}*"
                IMAGES="${FROM}/images/${YEAR}/${MONTH}/*"
                TO=${DEST}/${YEAR}

                mkdir -p $TO/{files,images/$YM}

                echo -e "\n-- Directory $TO --"
                echo cp -a $FILES $TO/files/
                cp -a $FILES $TO/files/
		echo "rename 'MC${YM}' 'MC_${YM}' $TO/files/*"
		echo "rename 'MC${YM}' 'MC_${YM}' $TO/files/*" | bash

                echo cp -a $IMAGES $TO/images/$YM/
                cp -a $IMAGES $TO/images/$YM/
#                echo "rename '/${YYMM}' '/MC_${YM}' $TO/images/$YM/*"
#                echo "rename '/${YYMM}' '/MC_${YM}' $TO/images/$YM/*" | bash
        done
done
