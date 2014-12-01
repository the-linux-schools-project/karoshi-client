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
intltool_extract_args=(
)

podir=l10n
pot=$podir/karoshi-client.pot
intltool_extract_tmp=$podir/tmp
mkdir "$intltool_extract_tmp"

# Process .desktop.template files
source l10n/desktop.sh.conf
for file in "${desktop_files[@]}"; do
	filename=${file##*/}
	#sed 's/^\(Name\|GenericName\|Comment\)/_\1/' "$file" > "$intltool_extract_tmp"/"$filename"
	cp "$file".in "$intltool_extract_tmp"/"$filename"
	intltool-extract --update --type=gettext/ini "${intltool_extract_args[@]}" \
		"$intltool_extract_tmp"/"$filename"
done

# Generate .pot
if [[ ! -e "$pot" ]] ||
  ( read -p "$pot already exists, overwrite? y/[n]: " response && [[ $response == y* ]] ); then
	xgettext -L shell -o "$pot" "${xgettext_args[@]}" "${files[@]}" 2>/dev/null
	xgettext -kN_:1 --join-existing -o "$pot" "${xgettext_args[@]}" "$intltool_extract_tmp"/*.h
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

rm -rf "$intltool_extract_tmp"
