#!/bin/bash
#
# This script provides useful bash functions to be reused in bash script.
#
# To use functions defined in this file, source this file:
#   . /etc/webobs.d/../CODE/shells/lib.bash
#

function woconf() {
	# Load variables from a webobs configuration file into the current
	# environment using a specific prefix.
	#
	# Arguments
	# ---------
	# prefix: the prefix to use for the environment variables to create.
	#         If not provided, defaults to 'WO__'.
	# src_config: the WEBOBS.rc variable designating the configuration file
	#             to read. If not provided, load WEBOBS.rc itself.
	#
	local prefix="${1:-WO__}" src_config="$2"

	# First unset any existing $prefix* variable from the environment
	unset $(printenv | awk -F= -v prefix="$prefix" '$0 ~ "^"prefix { print $1; }')

	# Export configuration variables read by exposerc.pl
	while IFS='' read -r definition; do
		export "$definition"
	done < <(perl /etc/webobs.d/../CODE/cgi-bin/exposerc.pl '=' "$prefix" "$src_config")
}
