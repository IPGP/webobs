#!/bin/bash

# ------------------------------------------------------------------------------
# Auto/unattended mode support.
#
# AUTO is set to true/false by the calling 'setup' script, once command-line
# options have been parsed (see setup's -a|--auto). When AUTO=true:
#   - confirm/confirmy no longer prompt interactively: they resolve to an
#     auto-default answer, optionally overridden by a shell variable sourced
#     from the file given with -c|--config <file>.
#   - readkb/readkbn no longer prompt interactively either: they return the
#     value of the override variable if set, or an empty string otherwise
#     (in which case the calling script applies its own built-in default,
#     exactly as if the user had hit [enter] on an empty answer).
#
# See SETUP/setup-auto.conf.default for the full list of override variables.
# ------------------------------------------------------------------------------
AUTO=${AUTO:-false}

# print a one-line note about an auto-resolved prompt; sent to stderr so it
# stays visible on screen/log without polluting $(...) command substitutions.
autonote () {
	echo -e "  [auto] $1" >&2
}

confirm () {
	# confirm "prompt" ["OVERRIDE_VARNAME"] ["auto-default(Y/N)"]
	# Interactive : prompts the user, empty/anything but y|Y means No.
	# Auto mode   : uses ${!OVERRIDE_VARNAME} if that variable is set and
	#               non-empty, otherwise falls back to "auto-default" (or
	#               N if none was given).
	local prompt="${1:-Are you sure? [y/N]}"
	local varname="$2"
	local autodefault="${3:-N}"
	if ${AUTO}; then
		local val="${autodefault}"
		if [[ -n "${varname}" && -n "${!varname}" ]]; then val="${!varname}"; fi
		autonote "${prompt}-> ${val}"
		case ${val} in
			[yY]|[yY][eE][sS]|true|TRUE)
				echo true;;
			*)
				echo false;;
		esac
		return
	fi
	local reply=''
	read -r -p "${prompt}" reply
	case $reply in
		[yY])
			echo true;;
		*)
			echo false;;
	esac
}

confirmy () {
	# same as confirm(), but defaults to Yes (both interactively - empty
	# reply means Yes - and in auto mode, unless an auto-default is given).
	local prompt="${1:-Are you sure? [Y/n]}"
	local varname="$2"
	local autodefault="${3:-Y}"
	if ${AUTO}; then
		local val="${autodefault}"
		if [[ -n "${varname}" && -n "${!varname}" ]]; then val="${!varname}"; fi
		autonote "${prompt}-> ${val}"
		case ${val} in
			[nN]|[nN][oO]|false|FALSE)
				echo false;;
			*)
				echo true;;
		esac
		return
	fi
	local reply=''
	read -r -p "${prompt}" reply
	case $reply in
		[yY]|'')
			echo true;;
		*)
			echo false;;
	esac
}

readkb () {
	# readkb "prompt" ["OVERRIDE_VARNAME"]
	# Interactive : loops until a non-empty answer is typed (value required).
	# Auto mode   : uses ${!OVERRIDE_VARNAME}; aborts if it is empty, since a
	#               value is mandatory here and there is no sane default.
	local prompt="${1:-?}"
	local varname="$2"
	if ${AUTO}; then
		local val=""
		if [[ -n "${varname}" ]]; then val="${!varname}"; fi
		autonote "${prompt}-> ${val}"
		if [[ -z "${val}" ]]; then
			echo "**** [auto] missing required value for '${prompt}'" >&2
			echo "     (set ${varname:-the relevant} variable in your --config file). Bye." >&2
			exit 64
		fi
		echo "${val}"
		return
	fi
	local reply=""
	while [[ "$reply" == "" ]]; do
		read -p "${prompt} " reply
	done
	echo $reply
}

readkbn () {
	# readkbn "prompt" ["OVERRIDE_VARNAME"]
	# Interactive : returns the typed answer, or "" on a bare [enter].
	# Auto mode   : returns ${!OVERRIDE_VARNAME} if set, else "" - in which
	#               case the calling script falls back to its own default,
	#               exactly as it would for an empty interactive answer.
	local prompt="${1:-?}"
	local varname="$2"
	if ${AUTO}; then
		local val=""
		if [[ -n "${varname}" ]]; then val="${!varname}"; fi
		autonote "${prompt}-> ${val:-<script default>}"
		echo "${val}"
		return
	fi
	local reply=""
	read -p "${prompt} " reply
	echo $reply
}

black='\E[30;40m'
red='\E[31;40m'
green='\E[32;40m'
yellow='\E[33;40m'
blue='\E[34;40m'
magenta='\E[35;40m'
cyan='\E[36;40m'
white='\E[37;40m'

cecho () {
	msg=${1:-??}   
	color=${2:-$black}   # Defaults to black
	echo -e "$color" 
	echo "$msg"
	tput sgr0            # Back to normal
	return
}
