#!/bin/bash

max_line_length=80
msgfilter_args=(
)
msgconv_args=(
	--to-code=UTF-8
)

function usage {
	echo "Usage:" >&2
	echo "  $0 [options] [lang]" >&2
	echo >&2
	echo "Options:" >&2
	echo "  --overwrite    Overwrite existing translations" >&2
}

overwrite=false
lang=
stage=1
sleep=5
while (( $# > 0 )); do
	case "$1" in
	--overwrite)
		overwrite=true
		;;
	--msgfilter)
		stage=2
		;;
	--sleep=*)
		sleep=${1#--sleep=}
		;;
	--help)
		usage
		exit 1
		;;
	*)
		if ! [[ $lang ]]; then
			lang="$1"
		else
			echo "ERROR: Too many arguments" >&2
		fi
		;;
	esac
	shift
done

case "$stage" in
1)
	msgfilter_exec_args=( --msgfilter )
	if $overwrite; then
		msgfilter_exec_args+=( --overwrite )
	fi

	function run_translate {
		echo -n "Translating $1" >&2
		msgconv "${msgconv_args[@]}" "$1" | msgfilter "${msgfilter_args[@]}" \
			"$0" "${msgfilter_exec_args[@]}" "$2"
		echo >&2
	}

	if [[ $lang ]]; then
		if [[ ! -f $lang.po ]]; then
			echo "No such file $lang.po" >&2
			exit 1
		fi
		run_translate "$lang".po "$lang" > "$lang".po.new
		mv "$lang".po.new "$lang".po
	else
		for po in *.po; do
			lang=${po%.po}
			run_translate "$po" "$lang" > "$po".new
			mv "$po".new "$po"
			# Don't overload Google
			sleep "$sleep"
		done
	fi
	;;
2)
	msgstr=
	while read -r line; do
		msgstr+=$line$'\n'
	done
	msgstr+=$line
	msgid=$MSGFILTER_MSGID
	if [[ $msgid ]]; then
		if [[ -z $msgstr ]] || $overwrite; then
			# Substitute variables out to prevent translation
			declare -A variable_map=( )
			str=$msgid
			parse_str=$msgid
			var_prefix=abcdef
			for var_index in {a..z}; do
				if [[ $parse_str != *\$* ]]; then
					break
				fi
				parse_str='$'${parse_str#*\$}
				if [[ $parse_str == \${* ]]; then
					var=${parse_str%%\}*}'}'
					parse_str=${parse_str#*\}}
				elif [[ $parse_str =~ ^(\$[a-zA-Z0-9_]*)(.*) ]]; then
					var=${BASH_REMATCH[1]}
					parse_str=${BASH_REMATCH[2]}
				else
					echo >&2
					echo "unable to process variable substitution" >&2
					exit 1
				fi
				variable_map["$var"]=$var_prefix$var_index
			done

			for var in "${!variable_map[@]}"; do
				str=${str/$var/${variable_map["$var"]}}
			done

			until msgstr=$(timeout 1 trs {en="$lang"} "$str"); do
				:
			done

			for var in "${!variable_map[@]}"; do
				old_msgstr=$msgstr
				subst=${variable_map["$var"]}
				msgstr=${msgstr/${subst,,}/$var} # lowercase
				msgstr=${msgstr/${subst^^}/$var} # UPPERCASE
				msgstr=${msgstr/${subst^}/$var} # CamelCase
				if [[ $old_msgstr == "$msgstr" ]]; then
					echo >&2
					echo "WARNING: Variable re-substitution failed for $msgid" >&2
					echo "  $var => $variable_map["$var"]}" >&2
				fi
			done
			echo -n '.' >&2
		fi
	fi
	echo -n "$msgstr"
	;;
esac
