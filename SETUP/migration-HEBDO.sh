#!/bin/bash

echo "Retrieve filenames from your webobs configuration ..."
oIFS=${IFS}; IFS=$'\n'
LEXP=($(perl /etc/webobs.d/../CODE/cgi-bin/exposerc.pl '=' 'WO__'))
for i in $(seq 0 1 $(( ${#LEXP[@]}-1 )) ); do export ${LEXP[$i]}; done
LEXP=($(perl /etc/webobs.d/../CODE/cgi-bin/exposerc.pl '=' 'HEBDO__' 'HEBDO_CONF'))
for i in $(seq 0 1 $(( ${#LEXP[@]}-1 )) ); do export ${LEXP[$i]}; done
hebdo=$HEBDO__FILE_NAME
types=$HEBDO__FILE_TYPE_EVENEMENTS
dbusers=$WO__SQL_DB_USERS


echo "Migrating $hebdo file..."
sed -i 's/|Astreinte|/|Duty|/' $hebdo
sed -i 's/|Absence|/|Holiday|/' $hebdo
sed -i 's/|Terrain|/|Field|/' $hebdo
sed -i 's/|Missions|/|Mission|/' $hebdo
sed -i 's/|[Rr].*union|/|Meeting|/' $hebdo
sed -i 's/|Vulgarisation|/|Outreach|/' $hebdo
sed -i 's/|Enseignement|/|Teaching|/' $hebdo
sed -i 's/|Visiteurs|/|Visitor|/' $hebdo
sed -i 's/|Stage|/|Training|/' $hebdo
sed -i 's/|Batiment|/|Building|/' $hebdo
sed -i 's/|Divers|/|Misc|/' $hebdo


echo "Migrating $types file..."
sed -i 's/^ToutReseaux/#ToutReseaux/' $types
sed -i 's/^Tout|/ALL|/' $types
sed -i 's/^Reseaux/Event/' $types
sed -i 's/^Astreinte/Duty/' $types
sed -i 's/^Absence/Holiday/' $types
sed -i 's/^Terrain/Field/' $types
sed -i 's/^Missions/Mission/' $types
sed -i 's/^Reunion/Meeting/' $types
sed -i 's/^Vulgarisation/Outreach/' $types
sed -i 's/^Enseignement/Teaching/' $types
sed -i 's/^Visiteurs/Visitor/' $types
sed -i 's/^Stage/Training/' $types
sed -i 's/^Batiment/Building/' $types
sed -i 's/^Divers/Misc/' $types


echo "Migrating HEBDO authorizations in $dbusers ..."
sqlite3 $dbusers <<EOF
BEGIN TRANSACTION;
update authmisc set RESOURCE='HEBDOALL' where RESOURCE='HEBDOTout';
update authmisc set RESOURCE='HEBDOEvent' where RESOURCE='HEBDOReseaux';
update authmisc set RESOURCE='HEBDODuty' where RESOURCE='HEBDOAstreinte';
update authmisc set RESOURCE='HEBDOHoliday' where RESOURCE='HEBDOAbsence';
update authmisc set RESOURCE='HEBDOField' where RESOURCE='HEBDOTerrain';
update authmisc set RESOURCE='HEBDOMission' where RESOURCE='HEBDOMissions';
update authmisc set RESOURCE='HEBDOMeeting' where RESOURCE='HEBDOReunion';
update authmisc set RESOURCE='HEBDOOutreach' where RESOURCE='HEBDOVulgarisation';
update authmisc set RESOURCE='HEBDOTeaching' where RESOURCE='HEBDOEnseignement';
update authmisc set RESOURCE='HEBDOVisitor' where RESOURCE='HEBDOVisiteurs';
update authmisc set RESOURCE='HEBDOTraining' where RESOURCE='HEBDOStage';
update authmisc set RESOURCE='HEBDOBuilding' where RESOURCE='HEBDOBatiment';
update authmisc set RESOURCE='HEBDOMisc' where RESOURCE='HEBDODivers';
COMMIT;
EOF
sqlite3 $dbusers 'select resource from authmisc where resource like "HEBDO%" order by 1;'

