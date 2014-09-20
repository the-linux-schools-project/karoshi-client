#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"/..

files=( linuxclientsetup/{scripts,utilities}/* )
languages=( ar cs da de el es fr he it nb pl pt ru sv zh )
xgettext_args=(
	--copyright-holder="The Linux Schools Project"
	--package-name=karoshi-client
	--package-version=4.2
	--msgid-bugs-address=rmccorkell@karoshi.org.uk
)
msginit_args=(
	--no-translator
)
msgmerge_args=(
)

podir=l10n
pot=$podir/karoshi-client.pot

# Generate .pot
if [[ ! -e "$pot" ]] ||
  ( read -p "$pot already exists, overwrite? y/[n]: " response && [[ $response == y* ]] ); then
	xgettext -L shell -o "$pot" "${xgettext_args[@]}" "${files[@]}" 2>/dev/null
	read -p "Edit $pot if necessary, then press Enter to continue"
fi

# Generate .po files
for lang in "${languages[@]}"; do
	if [[ -f "$podir"/"$lang".po ]]; then
		msgmerge --update "${msgmerge_args[@]}" "$podir"/"$lang".po "$pot"
		rm -f "$podir"/"$lang".po~
	else
		msginit --locale="$lang" --input="$pot" --output="$podir"/"$lang".po "${msginit_args[@]}"
	fi
done
