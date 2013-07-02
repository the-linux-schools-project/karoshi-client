#!/bin/bash

#Copyright (C) 2013 Robin McCorkell
#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#The Karoshi Team can be contacted either at mpsharrad@karoshi.org.uk or rmccorkell@karoshi.org.uk
#
#Website: http://www.karoshi.org.uk

###################
# !!! WARNING !!! #
###################

#This script WILL permanently modify your system, trashing
#configuration files and installing/removing packages. Use
#at your own risk!

###################
#Configuration checks
###################

echo "Performing configuration checks..."
echo

#Check if running as root (duh)
if [[ $EUID -ne 0 ]]; then
	echo "ERROR: Not running as root - aborting" >&2
	exit 1
fi

#Check for internet connection
if ! ping -w 1 -c 1 8.8.8.8; then
	echo "ERROR: No direct internet connection - aborting" >&2
	exit 1
fi

#Check for required packages
if ! (which apt-get); then
	echo "ERROR: Missing packages - aborting" >&2
	exit 1
fi

#Check if logged in as user with home in /home
if [[ ~ =~ ^/home ]]; then
	echo "ERROR: Current user has home area in /home" >&2
	echo "       Switch to different user to allow home directories to be moved correctly" >&2
	exit 1
fi

#Change directory to the script's location
cd "$( dirname "${BASH_SOURCE[0]}" )"

#Make sure our files are here
if ! ( [[ -d configuration ]] && [[ -d linuxclientsetup ]] && [[ -d install ]] ); then
	echo "ERROR: Missing files required for installation - aborting" >&2
	exit 1
fi

###################
#Pre-installation configuration
###################

echo "Preparing environment..."
echo "Warning: Do not interrupt the procedure or your system may be in"
echo "         an inconsistent state"

function set_network {
	# $1 = network interface
	# $2 = IP address/netmask
	# $3 = gateway
	( [[ $1 ]] && [[ $2 ]] && [[ $3 ]] ) || return
	ip link set "$1" up
	ip addr flush dev "$1"
	ip addr add "$2" dev "$1"
	ip route add default via "$3"
	
	#Set up resolv.conf for reliable DNS
	echo "nameserver 8.8.8.8
nameserver 8.8.4.4" > /etc/resolv.conf
}

#Save current network settings
net_int=$(ip route | sed -n 's/^default .*dev \([^ ]*\).*/\1/p')
net_ip=$(ip addr show eth0 | sed -n 's/^[[:space:]]*inet \([^ ]*\).*/\1/p')
net_gw=$(ip route | sed -n 's/^default .*via \([^ ]*\).*/\1/p')

#Add new APT repositories
if [[ -f install/apt-repositories ]]; then
	while read -r apt_repo; do
		add-apt-repository "$apt_repo"
	done < install/apt-repositories
fi

#Update APT
apt-get update

echo "Preparation finished!"
echo

###################
#Installation
###################

export DEBIAN_FRONTEND=noninteractive

#Install packages
if [[ -f install/install-list ]]; then
	echo "Installing packages..."
	packages=( $(< install/install-list) )
	#This is a bit of a hack to get error output stored in a variable as well as output
	exec 11>&1
	rm_packages=$(apt-get -y --allow-unauthenticated install ${packages[@]} 2>&1 >&11 | tee /dev/fd/2 | sed -n 's/^E: Unable to locate package //p'; exit ${PIPESTATUS[0]})
	err=$?
	exec 11>&-
	if [[ $err -eq 100 ]]; then
		while read -r rm_package; do
			packages=( $(sed "s/\<$rm_package\>//" <<< "${packages[@]}") )
		done <<< "$rm_packages"
		if [[ $packages ]]; then
			if ! apt-get -y --allow-unauthenticated install ${packages[@]}; then
				echo "ERROR: Failed to install packages" >&2
				echo "       Press Enter to continue" >&2
				read
			fi
		fi
	elif [[ $err -ne 0 ]]; then
		echo "ERROR: Failed to install packages" >&2
		echo "       Press Enter to continue" >&2
		read
	fi
fi

#Reset network settings in case a package clobbered it
set_network "$net_int" "$net_ip" "$net_gw"

#Remove packages
if [[ -f install/remove-list ]]; then
	echo "Removing packages..."
	packages=( $(< install/remove-list) )
	#This is a bit of a hack to get error output stored in a variable as well as output
	exec 11>&1
	rm_packages=$(apt-get -y purge ${packages[@]} 2>&1 >&11 | tee /dev/fd/2 | sed -n 's/^E: Unable to locate package //p'; exit ${PIPESTATUS[0]})
	err=$?
	exec 11>&-
	if [[ $err -eq 100 ]]; then
		while read -r rm_package; do
			packages=( $(sed "s/\<$rm_package\>//" <<< "${packages[@]}") )
		done <<< "$rm_packages"
		if [[ $packages ]]; then
			if ! apt-get -qy purge ${packages[@]}; then
				echo "ERROR: Failed to remove packages" >&2
				echo "       Press Enter to continue" >&2
				read
			fi
		fi
	elif [[ $err -ne 0 ]]; then
		echo "ERROR: Failed to remove packages" >&2
		echo "       Press Enter to continue" >&2
		read
	fi
fi

#Reset network settings in case a package clobbered it
set_network "$net_int" "$net_ip" "$net_gw"

#Update everything
echo "Updating packages..."
if ! apt-get -y --allow-unauthenticated dist-upgrade; then
	echo "ERROR: Failed to update packages" >&2
	echo "       Press Enter to continue" >&2
	read
fi

#Reset network settings in case a package clobbered it
set_network "$net_int" "$net_ip" "$net_gw"

#Clean up unneeded packages
echo "Autoremoving unneeded packages..."
if ! apt-get -qy autoremove; then
	echo "ERROR: Failed to autoremove packages" >&2
	echo "       Press Enter to continue" >&2
	read
fi

#Reset network settings in case a package clobbered it
set_network "$net_int" "$net_ip" "$net_gw"

#Install rubygems
if which gem && [[ -f install/rubygem-list ]]; then
	gems=( $(< install/rubygem-list) )
	if ! gem install ${gems[@]}; then
			echo "ERROR: Failed to install rubygems" >&2
			echo "       Press Enter to continue" >&2
			read
	fi
fi

#Create administrator user
[[ -e /opt/administrator ]] && rm -rf /opt/administrator
if ! useradd -d /opt/administrator -m -U -r administrator; then
	echo "Error in creating administrator user - removing existing user and trying again" >&2
	userdel administrator -r
	if ! useradd -d /opt/administrator -m -U -r administrator; then
		echo "ERROR: Unable to create administrator user" >&2
		echo "       Resolve manually, then press Enter to continue" >&2
		read
	fi
fi
if ! [[ -d ~administrator ]]; then
	echo "ERROR: We have a problem - administrator doesn't have a home directory" >&2
	exit 1
fi
#Set password and other parameters for administrator
echo "administrator:karoshi" | chpasswd
usermod -a -G adm,cdrom,sudo,dip,plugdev,lpadmin,sambashare -s /bin/bash

#Move home directories that currently exist in /home
while IFS=":" read -r username _ _ _ _ home _; do
	if [[ $home =~ ^/home ]]; then
		if ! usermod -d /opt/"$username" -m "$username"; then
			echo "ERROR: Moving home directory for $username has failed" >&2
			echo "       Press Enter to continue" >&2
			read <&1
		fi
	fi
done < <(getent passwd)

#Clean up /home
echo "Cleaning up /home..."
find /home -mindepth 1 -delete

#Copy in new configuration (overwrite)
echo "Installing configuration..."
find configuration -mindepth 1 -maxdepth 1 -not -name '*~' -print0 | xargs -0 cp -rf -t /

find linuxclientsetup/admin-skel -mindepth 1 -maxdepth 1 -print0 | xargs -0 cp -rf -t ~administrator
chown -R administrator:administrator ~administrator

#Correct permissions for sudoers.d files
find /etc/sudoers.d -mindepth 1 -maxdepth 1 -execdir chmod -R 0440 {} +

#Install linuxclientsetup
[[ -e /opt/karoshi ]] && rm -rf /opt/karoshi
mkdir /opt/karoshi
cp -rf linuxclientsetup /opt/karoshi
find /opt/karoshi/linuxclientsetup -name '*~' -delete

chmod 755 /opt/karoshi/linuxclientsetup/scripts/*
chmod 755 /opt/karoshi/linuxclientsetup/utilities/*
chmod 644 /opt/karoshi/linuxclientsetup/utilities/*.conf

#Link karoshi-run-script
ln -sf karoshi-run-script /usr/bin/karoshi-set-local-password
ln -sf karoshi-run-script /usr/bin/karoshi-set-location
ln -sf karoshi-run-script /usr/bin/karoshi-set-network
ln -sf karoshi-run-script /usr/bin/karoshi-setup
ln -sf karoshi-run-script /usr/bin/karoshi-manage-flags
ln -sf karoshi-run-script /usr/bin/karoshi-virtualbox-mkdir
ln -sf karoshi-run-script /usr/bin/karoshi-pam-wrapper

echo
echo "Installation of Karoshi Client complete - press Ctrl + C now to finish"
echo "Alternatively, press Enter to continue to remaster the current system"
read

###################
#Start remastersys
###################
echo "Beginning remaster..."

if ! which remastersys; then
	echo "ERROR: No remastersys detected - aborting" >&2
	exit 1
fi

#Link karoshi-setup
[[ -d ~administrator/.config/autostart/ ]] || mkdir -p ~administrator/.config/autostart/
ln -sf /opt/karoshi/linuxclientsetup/karoshi-setup.desktop ~administrator/.config/autostart/
chown -R administrator:administrator ~administrator

#Administrator autologin
if ! grep "^autologin-user=" /etc/lightdm/lightdm.conf; then
	echo "autologin-user=administrator
autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf
fi

#Determine ISO parameters
if [[ -f README.md ]]; then
	iso_version=$(sed -n 's/.*\*\*Current dev version:\*\* \(.*\)/\1/p' README.md)
	iso_website=$(sed -n 's/.*\*\*Website:\*\* \(.*\)/\1/p' README.md)
else
	echo "WARNING: No README.md detected, using timestamp as version" >&2
	iso_version=$(date +%s)
	iso_website="http://linuxgfx.co.uk/"
fi
#Determine ISO architecture
iso_arch=$(uname -i)
[[ $iso_arch == x86_64 ]] && iso_arch=amd64

echo "ISO Label:   Karoshi Client $iso_version-$iso_arch"
echo "ISO Website: $iso_website"

#Configure remastersys
sed -i -e "s@^WORKDIR=.*@WORKDIR='/tmp'@" \
	   -e "s@^EXCLUDES=.*@EXCLUDES='/tmp /mnt'@" \
	   -e "s@^LIVEUSER=.*@LIVEUSER='administrator'@" \
	   -e "s@^LIVECDLABEL=.*@LIVECDLABEL='Karoshi Client $iso_version-$iso_arch'@" \
	   -e "s@^CUSTOMISO=.*@CUSTOMISO='karoshi-client-$iso_version-$iso_arch.iso'@" \
	   -e "s@^LIVECDURL=.*@LIVECDURL='$iso_website'@" \
	   /etc/remastersys.conf

#Configure boot menu image
if [[ -e install/splash.png ]]; then
	echo "Found custom splash.png"
	[[ -e /etc/remastersys/isolinux/splash.png ]] && rm -f /etc/remastersys/isolinux/splash.png
	cp install/splash.png /etc/remastersys/isolinux/splash.png
fi
#Configure preseed
if [[ -e install/preseed.cfg ]]; then
	echo "Found custom preseed.cfg"
	[[ -e /etc/remastersys/preseed/custom.seed ]] && rm -f /etc/remastersys/preseed/custom.seed
	cp install/preseed.cfg /etc/remastersys/preseed/custom.seed
fi

#Start creating the remaster
if ! remastersys clean; then
	echo "WARNING: Error in cleaning remastersys working directory (/tmp/remastersys)" >&2
	echo "         Resolve manually, then press Enter to continue" >&2
	read
fi
if ! remastersys backup; then
	echo "ERROR: remastersys backup failed" >&2
else
	echo
	echo "Remaster complete!"
	echo "ISO Location: /tmp/remastersys"
	echo "ISO Filename: karoshi-client-$iso_version-$iso_arch.iso"
	echo "ISO Checksum: karoshi-client-$iso_version-$iso_arch.iso.md5"
	echo
fi

###################
#Clean up
###################

echo "Cleaning up..."
rm -f ~administrator/.config/autostart/karoshi-setup.desktop
#Stop Auto logon
sed -i 's/^autologin/#autologin/' /etc/lightdm/lightdm.conf
