#!/bin/bash
P=`dirname $0`
. ${P}/dutils.sh

IFS=$'\n'
LEXP=($(perl ../CODE/perl/exposerc.pl '=' 'WO__'))
for i in $(seq 0 1 $(( ${#LEXP[@]}-1 )) ); do export ${LEXP[$i]}; done

# checks consistency between the webobs db users and the htaccess file:
#   - logins of invalid users will be commented
#   - logins of inexisting users will be deleted
#
# current directory (pwd) MUST be the target webob's CONF/ directory

echo "Check all Apache logins in $WO__HTTP_PASSWORD_FILE file..."
tobecommented=()
tobedeleted=()
while IFS= read -r line
do
    if [[ ! -z $line && $line != \#* ]]; then
        login=$(echo $line | cut -f1 -d:)
        printf "  $login: "
        S=$(sqlite3 $WO__SQL_DB_USERS "SELECT VALIDITY,UID FROM users WHERE LOGIN = '$login'")
        U=$(echo $S | cut -f2 -d\|)
        if [[ $S == Y\|* ]]; then
            echo "known and valid user ($U)."
        elif [[ $S == N\|* ]]; then
            echo "known but INVALID user ($U)! ==> login must be commented."
            tobecommented+=($login)
        else
            echo "UNKNOWN user! ==> login must be deleted."
            tobedeleted+=($login)
        fi  
    fi
done < $WO__HTTP_PASSWORD_FILE

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