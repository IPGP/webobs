#!/bin/bash

KEYS=""
CLBFIELDS_FILE="${RELBASE}/CODE/etc/clbfields.conf"

main() {
	P=$(dirname $0)
	R=$(dirname ${P})
	. ${R}/dutils.sh

	TMP_CLB=$(mktemp /tmp/clb_XXXXXXXXXXXXXXXX) || { echo "Installation failed!"; exit 1; }
	trap 'rm -f -- "${TMP_CLB}"; shopt -u nullglob;' EXIT
	shopt -s nullglob

	CLBUPDATE="false"
	for INFILE in "${DOCROOT}"/DATA/NODES/*/*.clb ; do
		if [[ ! $(grep "^=key|" "${INFILE}") ]] && [[ -s "${INFILE}" ]]; then
			CLBUPDATE="true"
			break
		fi
	done

	if [[ "${CLBUPDATE}" == "false" ]]; then
		exit 0
	fi

	echo "********************************************************************"
	echo "*********** Calibration files (clb) have to be updated. ************"
	echo "**** It's highly recommended to back up the WebObs DATA folder. ****"
	echo "********************************************************************"
	echo
	if $(confirmy "Do you want to update calibration files and continue with the installation [Y/n] ?"); then
		if [[ -f "${CLBFIELDS_FILE}" ]]; then
			if [[ ! $(grep "^=key|" "${CLBFIELDS_FILE}") ]]; then
				echo "Older version of ${CLBFIELDS_FILE} found. Installation canceled!"
				exit 1
			fi
		fi
		update_clb
		if [[ -n "${USERID}" ]]; then
			chown -R "${USERID}:${USERGID}" "${DOCROOT}"/DATA
		fi
		chmod -R 775 "${DOCROOT}"/DATA
	else
		echo "Installation canceled by user."
		exit 1
	fi
}

update_clb() {
	while read -r LINE; do
		if ! ( [[ "${LINE}" =~ ^#.* ]] || [[ "${LINE}" =~ ^=key.* ]] || [[ -z "${LINE}" ]] ); then
			KEYS+="|$(echo "${LINE}" | cut -d "|" -f 1)"
		fi
	done < "${CLBFIELDS_FILE}"
	KEYS="=key${KEYS}"
	NUM_SEP=$(grep -o "|" <<< "${KEYS}" | wc -l)

	for INFILE in "${DOCROOT}"/DATA/NODES/*/*.clb ; do
		if [[ $(grep "^=key|" "${INFILE}") ]]; then
			echo "${INFILE} is already updated."
			continue
		elif [[ ! -s "${INFILE}" ]]; then
			continue
		fi

		COUNTER=0
		HASHLINE=0
		while read -r LINE; do
			#printf '%s\n' "${LINE}"
			if [[ "${LINE}" =~ ^#.* ]]; then
				printf "%s\n" "${LINE}" >> "${TMP_CLB}"
			elif [[ -n "${LINE}" ]]; then
				if [[ ${HASHLINE} == 0 ]]; then
					HASHLINE=$((HASHLINE+1))
					echo "${KEYS}" >> "${TMP_CLB}"
				fi
				COUNTER=$((COUNTER+1))
				DIFF=$(("${NUM_SEP}" - $(grep -o "|" <<< "${LINE}" | wc -l)))
				SEPARATORS=$(printf '|%.0s' $(seq "${DIFF}"))
				if [[ "${DIFF}" -gt 1 ]]; then
					printf "%s|%s%s\n" "${COUNTER}" "${LINE}" "${SEPARATORS}" >> "${TMP_CLB}"
				else
					printf "%s|%s\n" "${COUNTER}" "${LINE}" >> "${TMP_CLB}"
				fi
			fi
		done < "${INFILE}"

		if [[ -f "${TMP_CLB}" ]]; then
			cp "${INFILE}" "${INFILE}.bak"
			mv "${TMP_CLB}" "${INFILE}"
			echo "${INFILE} updated."
		fi
	done
}

main "$@"; exit

