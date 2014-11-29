#!/bin/bash

#Copyright (C) 2013,2014 Robin McCorkell

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

source_dir=${BASH_SOURCE[0]}
source_dir=${source_dir%/*}

if [[ ! -f $source_dir/install/cleanup.sh ]]; then
	echo "Unable to find required source files" >&2
	exit 1
fi
source "$source_dir"/install/cleanup.sh
source "$source_dir"/install/config

#Hooks
function hook {
	if [[ $1 ]] && [[ -f $source_dir/install/hook/$1 ]]; then
		source "$source_dir"/install/hook/"$1"
	fi
}

#All hooks:
# - usage     Print usage
# - opt-parse Option parsing

#First stage hooks:
# - pre-fakechroot
# - post-fakechroot

#Second stage hooks:
# - pre-debootstrap
# - post-debootstrap
# - pre-chroot
# - post-chroot
# - post-chroot-cleanup
# - pre-mksquashfs
# - post-mksquashfs
# - pre-iso
# - post-iso

#Third stage hooks:
# - ppa-cmd        PPA command
# - pre-apt        Pre installation
# - apt-install    Install packages
# - apt-opt        Add apt option for installation
# - apt-stop       Stop package installation
# - post-apt       Post package installation
# - pre-custom     Pre custom installation
# - post-custom    Post custom installation

#Usage
function usage {
	echo "Usage:" >&2
	echo "	$0 [options] --dir=<directory>" >&2
	echo >&2
	echo " Options:" >&2
	echo "  --arch=<arch>        Architecture [i386|amd64]" >&2
	echo "  --dir=<directory>    Location of work directory" >&2
	echo "  --release=<version>  Create release version" >&2
	echo "  --apt-proxy=<proxy>  Define apt proxy (http://server:port)" >&2
	echo "  --help               Show this help message" >&2
	hook usage
}

#Options
stage=1
apt_proxy=$http_proxy
while (( "$#" )); do
	case "$1" in
	--arch=*)
		arch=${1##--arch=}
		;;
	--dir=*)
		work_dir=${1##--dir=}
		;;
	--release=*)
		release=${1##--release=}
		;;
	--apt-proxy=*)
		apt_proxy=${1##--apt-proxy=}
		;;
	--help)
		usage
		exit 1
		;;
	--second-stage)
		stage=2
		;;
	--third-stage)
		stage=3
		;;
	*)
		if ! hook opt-parse "$1"; then
			echo "Unrecognized option $1" >&2
			exit 254
		fi
		;;
	esac
	shift
done

function apt-get {
	http_proxy="$apt_proxy" command apt-get "$@" </dev/null
}

if [[ -z $work_dir ]]; then
	echo "You must set a work directory with --dir" >&2
	exit 254
fi
if [[ ! -d $work_dir ]]; then
	echo "$work_dir does not exist" >&2
	exit 252
fi

#Absolutify work_dir
if [[ $work_dir != /work ]]; then
	work_dir=$(readlink -f "$work_dir")
fi

case "$stage" in
1)
	##############################
	# First stage - initialization
	##############################
	if ! which fakeroot fakechroot > /dev/null; then
		echo "This script requires fakeroot and fakechroot to be installed" >&2
		exit 252
	fi
	if ! which mksquashfs mkisofs > /dev/null || [[ ! -f /usr/lib/syslinux/isolinux.bin ]]; then
		echo "This script requires syslinux, squashfs-tools and genisoimage to be installed" >&2
		exit 252
	fi
	if ! which debootstrap > /dev/null; then
		echo "Unable to find debootstrap" >&2
		echo "Download and install .deb for $ubuntu_release from" \
			"http://packages.ubuntu.com/search?keywords=debootstrap&searchon=names&suite=all&section=all" >&2
		exit 252
	fi

	source_dir=$(readlink -f "$source_dir")

	: ${release:=git-$(cd "$source_dir" && git rev-parse --short HEAD)}
	: ${arch:=$(dpkg --print-architecture)}

	#Prepare fakechroot
	declare -A cmd_subst=(
		[/usr/bin/chfn]="$source_dir"/install/chfn.fakechroot
		[/usr/bin/ldd]="$source_dir"/install/ldd.fakechroot
	)
	for cmd in "${!cmd_subst[@]}"; do
		FAKECHROOT_CMD_SUBST+=":$cmd=${cmd_subst[$cmd]}"
	done
	export FAKECHROOT_CMD_SUBST=${FAKECHROOT_CMD_SUBST#:}

	fakeroot_args=( -s "$work_dir"/fakeroot.save )
	if [[ -f "$work_dir"/fakeroot.save ]]; then
		fakeroot_args+=( -i "$work_dir"/fakeroot.save )
	fi

	hook pre-fakechroot

	fakechroot -e debootstrap -- fakeroot "${fakeroot_args[@]}" -- \
		"$source_dir"/install.sh --second-stage --dir="$work_dir" \
			--arch="$arch" --release="$release" --apt-proxy="$apt_proxy"

	hook post-fakechroot
	;;
2)
	####################################
	# Second stage - fakechroot fakeroot
	####################################
	mkdir -p "$work_dir"/image/{casper,isolinux,install}
	root=$work_dir/chroot

	if [[ ! -d "$root" ]]; then
		mkdir "$root"

		hook pre-debootstrap

		#debootstrap
		ubuntu_release=$(sed -n 's/^#!release //p' "$source_dir"/install/sources.list)
		http_proxy="$apt_proxy" debootstrap --variant=fakechroot \
			--include=wget --arch="$arch" "$ubuntu_release" "$root"

		#debootstrap workarounds
		if [[ -L "$root"/dev ]]; then
			rm -f "$root"/{dev,proc}
			mkdir "$root"/{dev,proc}
		fi
		function remove_debootstrap_diversion {
			if [[ -f $root$1.REAL ]]; then
				rm -f "$root""$1"
				mv -f "$root""$1".REAL "$root""$1"
				sed -i "\@^$1\$@,/^fakechroot\$/d" "$root"/var/lib/dpkg/diversions
			fi
		}
		remove_debootstrap_diversion /sbin/ldconfig
		remove_debootstrap_diversion /usr/bin/ldd

		hook post-debootstrap
	fi

	#Fix symlinks
	while read -r symlink; do
		link_dest=$(readlink -f "$symlink")
		if [[ $link_dest != $root/* ]]; then
			echo "Fixing symlink $symlink -> $link_dest" >&2
			rm -f "$symlink"
			ln -sfT "${root}${link_dest}" "$symlink"
		fi
	done < <(find "$root" -lname /'*')

	#Create links and copy required files
	ln -sfT "$source_dir" "$root"/source
	ln -sfT "$work_dir" "$root"/work
	cp -ft "$root"/etc /etc/resolv.conf "$source_dir"/install/hosts
	cleanup_file_add "$root"/{source,work,etc/resolv.conf}

	hook pre-chroot

	chroot "$root" /source/install.sh --third-stage \
		--dir=/work --arch="$arch" --release="$release" --apt-proxy="$apt_proxy"

	hook post-chroot

	cleanup

	hook post-chroot-cleanup

	#Fix symlinks
	while read -r symlink; do
		link_dest=$(readlink -f "$symlink")
		echo "Fixing symlink $symlink -> $link_dest" >&2
		rm -f "$symlink"
		ln -sfT "${link_dest##"$root"}" "$symlink"
	done < <(find "$root" -lname "$root"/'*')

	#Configure isolinux
	cp -ft "$work_dir"/image/isolinux /usr/lib/syslinux/{isolinux.bin,vesamenu.c32}
	if [[ -f /boot/memtest86+.bin ]]; then
		cp -f /boot/memtest86+.bin "$work_dir"/image/install/memtest
	fi

	cp -ft "$work_dir"/image/isolinux "$source_dir"/install/isolinux.cfg
	cp -ft "$work_dir"/image "$source_dir"/install/README.diskdefines
	cp -ft "$work_dir"/image/casper "$source_dir"/install/preseed.cfg
	sed -i -e "s/@VERSION@/$release/g" -e "s/@ARCH@/$arch/g" \
		"$work_dir"/image/{isolinux/isolinux.cfg,README.diskdefines}
	if which convert >/dev/null; then
		convert "$source_dir"/install/splash.png -resize 640x480^ -crop 640x480+0+0 \
			"$work_dir"/image/isolinux/splash.png
	else
		cp -ft "$work_dir"/image/isolinux "$source_dir"/install/splash.png
	fi

	#Create filesystem.squashfs
	if [[ -f $work_dir/image/casper/filesystem.squashfs ]]; then
		rm -f "$work_dir"/image/casper/filesystem.squashfs
	fi

	hook pre-mksquashfs

	mksquashfs "$root" "$work_dir"/image/casper/filesystem.squashfs \
		-no-recovery -always-use-fragments -b 1M -no-duplicates -e boot/grub
	printf $(du -sx --block-size=1 "$root" | cut -f1) > "$work_dir"/image/casper/filesystem.size

	hook post-mksquashfs

	#Set Ubuntu metadata
	echo -n > "$work_dir"/image/ubuntu
	mkdir -p "$work_dir"/image/.disk
	echo -n > "$work_dir"/image/.disk/base_installable
	echo "full_cd/single" > "$work_dir"/image/.disk/cd_type
	echo "$ISO_TITLE_BASE $release" > "$work_dir"/image/.disk/info
	echo "$URL" > "$work_dir"/image/.disk/release_notes_url

	#Create md5sum
	(
		cd "$work_dir"/image
		find . -type f -exec md5sum {} + | grep -v '\./md5sum.txt' > md5sum.txt
	)

	#Create ISO
	iso_filename=${ISO_TITLE_BASE// /-}-${release}-${arch}.iso
	iso_filename=${iso_filename,,}
	if [[ -f $work_dir/$iso_filename ]]; then
		rm -f "$work_dir"/"$iso_filename"
	fi

	hook pre-iso

	mkisofs -r -V "$ISO_TITLE_BASE $release $arch" -cache-inodes -J -l \
		-b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
		-boot-load-size 4 -boot-info-table \
		-o "$work_dir"/"$iso_filename" "$work_dir"/image

	hook post-iso
	;;
3)
	######################
	# Third stage - chroot
	######################
	shopt -s dotglob
	mkdir -p /etc/apt
	cp -ft /etc/apt "$source_dir"/install/sources.list
	export DEBIAN_FRONTEND=noninteractive

	#Get GPG keys for PPAs
	while read -r cmd; do
		hook ppa-cmd
		eval "$cmd"
	done < <(sed -n 's/^#!cmd //p' "$source_dir"/install/sources.list)

	#Allow apt to work properly in a chroot
	dpkg-divert --local --rename --add /sbin/initctl
	cleanup_func_add dpkg-divert --rename --remove /sbin/initctl
	ln -sfT /bin/true /sbin/initctl
	cleanup_func_add rm /sbin/initctl
	dpkg-divert --local --rename --add /usr/sbin/invoke-rc.d
	cleanup_func_add dpkg-divert --rename --remove /usr/sbin/invoke-rc.d
	ln -sfT /bin/true /usr/sbin/invoke-rc.d
	cleanup_func_add rm /usr/sbin/invoke-rc.d

	#Architecture-specific tweaks
	dpkg_arch=$(dpkg --print-architecture)
	case "$dpkg_arch" in
	amd64)
		dpkg --add-architecture i386
		;;
	esac

	apt-get update
	apt-get install --yes dbus
	dbus-uuidgen > /var/lib/dbus/machine-id
	cleanup_file_add /var/lib/dbus/machine-id

	hook pre-apt

	#Required software
	apt-get install --yes ubuntu-standard casper lupin-casper discover \
		laptop-detect os-prober linux-generic

	#Remember to have ubiquity-frontend-* in install/install.list
	install_packages=( ubiquity ubiquity-casper grub2 )
	opts=( )
	if [[ -f "$source_dir"/install/install.list ]]; then
		while read -r pkg; do
			case "$pkg" in
			"#!install")
				if [[ $install_pkgs ]]; then
					hook apt-install
					apt-get install --yes "${opts[@]}" "${install_pkgs[@]}"
				fi
				install_pkgs=( )
				opts=( )
				;;
			"#!opt "*)
				hook apt-opt
				opt=${pkg##"#!opt "}
				opts+=( "$opt" )
				;;
			"#!stop")
				echo "DEBUG: Executing apt-get install ${opts[@]} ${install_pkgs[@]}" >&2
				hook apt-stop
				apt-get install "${opts[@]}" "${install_pkgs[@]}"
				exit 2
				;;
			"#"*)
				;;
			"")
				;;
			*)
				install_pkgs+=( $pkg )
				;;
			esac
		done < "$source_dir"/install/install.list
	fi
	if [[ $install_pkgs ]]; then
		hook apt-install
		apt-get install --yes "${opts[@]}" "${install_pkgs[@]}"
	fi

	apt-get dist-upgrade --yes

	function disable_script {
		for arg in "$@"; do
			echo "Disabling $arg" >&2
			dpkg-divert --local --add "$arg"
			cat > "$arg" <<- EOF
				#!/bin/sh
				exit 0 #disabled
			EOF
		done
	}
	#Prevent CD being added as apt repository, and prevent attempted user creation
	disable_script /usr/share/ubiquity/apt-setup
	disable_script /usr/lib/ubiquity/user-setup/user-setup-apply
	disable_script /usr/share/initramfs-tools/scripts/casper-bottom/{25adduser,41apt_cdrom}

	hook post-apt

	#Copy in new configuration (overwrite)
	hook pre-custom
	cp -rft / "$source_dir"/configuration/*
	hook post-custom

	#Correct permissions for sudoers.d files
	find /etc/sudoers.d -mindepth 1 -maxdepth 1 -execdir chmod -R 0440 {} +

	#Create links with update-alternatives
	if [[ -f "$source_dir"/install/alternatives.list ]]; then
		while read -r alternative_name link_name _ link_to; do
			if [[ $link_name ]] && [[ $alternative_name ]] && [[ $alternative_name != \#* ]] && [[ -e $link_to ]]; then
				update-alternatives --install "$link_name" "${alternative_name%:}" "$link_to" 100
			fi
		done < "$source_dir"/install/alternatives.list
	fi

	apt-get clean --yes

	#Regenerate initramfs
	update-initramfs -u

	#Copy kernel and initrd to image directory
	cp -f /boot/vmlinuz-* "$work_dir"/image/casper/vmlinuz
	cp -f /boot/initrd.img-* "$work_dir"/image/casper/initrd.gz

	#Create filesystem manifest
	dpkg-query -W --showformat='${Package} ${Version}\n' > "$work_dir"/image/casper/filesystem.manifest
	cp -f "$work_dir"/image/casper/filesystem.manifest "$work_dir"/image/casper/filesystem.manifest-desktop
	sed -i -e '/ubiquity/d' -e '/casper/d' "$work_dir"/image/casper/filesystem.manifest-desktop
	;;
esac

