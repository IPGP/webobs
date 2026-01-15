#!/bin/bash
# check-user-access.sh
#
# Author: François Beauducel, WEBOBS
# Created: 2026-01-14 in La Plaine des Cafres (La Réunion)
# Updated: 2026-01-15

[[ "$@" =~ 'clean' ]] && clean=true

if [[ $# -eq 0 ]]; then
    echo "Syntax: check-user-access.sh [clean]"
    echo
    echo "checks consistency between the webobs db users and the htaccess file:"
    echo "  - logins of invalid users will be commented"
    echo "  - logins of inexisting users will be deleted"
    echo
    echo "current directory (pwd) MUST be the target webob's CONF/ directory."
    echo "argument 'clean' makes the job. Any other argument makes a dry run."
    exit 0
fi

P=`dirname $0`

# imports all WEBOBS.rc variables
IFS=$'\n'
LEXP=($(perl $P/../CODE/perl/exposerc.pl '=' 'WO__'))
for i in $(seq 0 1 $(( ${#LEXP[@]}-1 )) ); do export ${LEXP[$i]}; done


echo "Check all Apache logins in $WO__HTTP_PASSWORD_FILE file..."
active=0
commented=0
tobecommented=()
tobedeleted=()
while IFS= read -r line
do
    if [[ ! -z $line && $line != \#* ]]; then
        ((active++))
        login=$(echo $line | cut -f1 -d:)
        printf "  $login: "
        safe_login=${login//\'/\'\'}
        S=$(sqlite3 $WO__SQL_DB_USERS "SELECT VALIDITY,UID,FULLNAME FROM users WHERE LOGIN = '$safe_login'")
        U=$(echo $S | cut -f2 -d\|)
        N=$(echo $S | cut -f3 -d\|)
        if [[ $S == Y\|* ]]; then
            echo "known and valid user '$N ($U)'."
        elif [[ $S == N\|* ]]; then
            echo "known but INVALID user '$N ($U)'! ==> login must be commented."
            tobecommented+=($login)
        else
            echo "UNKNOWN user! ==> login must be deleted."
            tobedeleted+=($login)
        fi  
    fi
    if [[ $line == \#*:* ]]; then
        ((commented++))
    fi

done < $WO__HTTP_PASSWORD_FILE

echo
echo "Logins summary:"
echo "  total active = $active"
echo "  to be commented = ${#tobecommented[@]}"
echo "  to be deleted = ${#tobedeleted[@]}"
echo "  commented (ignored) = $commented"

if [[ ${#tobecommented[@]} == 0 && ${#tobedeleted[@]} == 0 ]]; then
    echo "User access logins consistent between Apache htpasswd and WebObs database."
    exit 0
else
    echo
    echo "--> !! Potential security issue: some user access logins must be cleaned."
fi

if [[ $clean = true ]]; then

    # backup the file
    bkp="$WO__HTTP_PASSWORD_FILE.backup$(date +%Y%m%dT%H%M%S)"
    cp -a $WO__HTTP_PASSWORD_FILE $bkp
    echo "--> Former htaccess file has been backup as $bkp."

    # comment some logins
    regex=$(printf '^%s:|' "${tobecommented[@]}")
    regex=${regex%|}
    sed -i -E "/^[[:space:]]*#/! s/($regex)/#&/" "$WO__HTTP_PASSWORD_FILE"
    echo "--> ${#tobecommented[@]} logins have been commented."

    # delete some logins
    regex=$(printf '^%s:.*$|' "${tobedeleted[@]}")
    regex=${regex%|}
    sed -i -E "/^[[:space:]]*#/! s/($regex)//" "$WO__HTTP_PASSWORD_FILE"
    echo "--> ${#tobedeleted[@]} logins have been deleted."
    echo "The security issues have now been resolved."
else
    echo "--> Dry run. Nothing has been done."
fi