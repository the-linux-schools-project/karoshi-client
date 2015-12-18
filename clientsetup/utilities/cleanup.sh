#!/bin/bash

#Copyright (C) 2014 Robin McCorkell <rmccorkell@karoshi.org.uk>

#This file is part of Karoshi Client.
#
#Karoshi Client is free software: you can redistribute it and/or modify
#it under the terms of the GNU Affero General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#Karoshi Client is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU Affero General Public License for more details.
#
#You should have received a copy of the GNU Affero General Public License
#along with Karoshi Client.  If not, see <http://www.gnu.org/licenses/>.

#Exit codes:
# 0   success
# 252 controlled error
# 253 reserved
# 254 usage error
# *   general error, backtrace

set -e

cleanup_funcs=( )
cleanup_files=( )

# functions to be run on cleanup
function cleanup_func_add {
	if [[ -z $* ]]; then return 1; fi
	cleanup_funcs=( "$*" "${cleanup_funcs[@]}" )
}
function cleanup_func_remove {
	if [[ -z $* ]]; then return 1; fi
	local new_funcs=( ) func
	for func in "${cleanup_funcs[@]}"; do
		if [[ $func != $* ]]; then
			new_funcs+=( "$func" )
		fi
	done
	cleanup_funcs=( "${new_funcs[@]}" )
}

# files and directories to be removed on cleanup
function cleanup_file_add {
	if [[ -z $@ ]]; then return 1; fi
	local file
	for file in "$@"; do
		cleanup_files=( "$file" "${cleanup_files[@]}" )
	done
}
function cleanup_file_remove {
	if [[ -z $@ ]]; then return 1; fi
	local new_files file arg
	for arg in "$@"; do
		new_files=( )
		for file in "${cleanup_files[@]}"; do
			if [[ $file != $arg ]]; then
				new_files+=( "$file" )
			fi
		done
		cleanup_files=( "${new_files[@]}" )
	done
}

# cleanup
function cleanup_reset {
	cleanup_funcs=( )
	cleanup_files=( )
}
function cleanup {
	for func in "${cleanup_funcs[@]}"; do
		$func
	done
	for file in "${cleanup_files[@]}"; do
		if [[ -e $file ]]; then
			rm -rf "$file"
		fi
	done
	cleanup_reset
}

################
# Error handling
################

# default usage
function usage {
	echo "Usage:" >&2
	echo "  $0 [options]" >&2
}

function error_handler {
	set +e
	cleanup

	case $1 in
	0)
		return
		;;
	252)
		exit 252
		;;
	253)
		(( i = 0 ))
		while read -r lineno func file < <(caller $i); do
			echo "$file:$func:$lineno" >&2
			(( ++i ))
		done
		;;
	254)
		usage
		exit 252
		;;
	*)
		echo >&2
		echo "An error has occurred!" >&2
		read -r lineno func file < <(caller 0)
		echo "$file:$func:$lineno: exit status $1" >&2
		echo >&2
		echo "Backtrace:" >&2
		(( i = 0 ))
		while read -r lineno func file < <(caller $i); do
			echo "$file:$func:$lineno" >&2
			(( ++i ))
		done

		exit 253
		;;
	esac
}

trap 'error_handler $?' EXIT
trap exit ERR
