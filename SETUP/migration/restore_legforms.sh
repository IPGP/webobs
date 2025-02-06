#!/bin/bash
# needs admin rights to run

WOCONF=$(readlink /etc/webobs.d)
WO=$(cd $WOCONF/.. && pwd)
echo "WebObs root dir is $WO"

for f in $(ls -d CONF/LEGACY_FORMS/FORMS/*); do
	form=$(basename $f)
	rm -f CONF/GRIDS2NODES/FORM.$form.*
	rm -rf CONF/FORMS/$form
	mv $f CONF/FORMS/
	mv -f CONF/LEGACY_FORMS/GRIDS2FORMS/PROC.*.$form CONF/GRIDS2FORMS/
    DAT=$(grep ^FILE_NAME CONF/FORMS/$form.conf | cut -d '|' -f 2)
    mv -f DATA/BACKUP_LEGACY_FORMS/$DAT DATA/DB/
	echo "--> legacy form $form restored. Downgrade WebObs to release 2.7 or previous."
done
