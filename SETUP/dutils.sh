#!/bin/bash

confirm () {
	# call confirm('prompt') or will use default N
	local reply=''
	read -r -p "${1:-Are you sure? [y/N]} " reply
	case $reply in
		[yY]) 
			echo true;;
		*)
			echo false;;
	esac
}

confirmy () {
	# call confirm('prompt') or will use default Y
	local reply=''
	read -r -p "${1:-Are you sure? [Y/n]} " reply
	case $reply in
		[yY]|'')
			echo true;;
		*)
			echo false;;
	esac
}

readkb () {
	local reply=""
	while [[ "$reply" == "" ]]; do
		read -p "${1:-?} " reply
	done
	echo $reply
}

readkbn () {
	local reply=""
	read -p "${1:-?} " reply
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
