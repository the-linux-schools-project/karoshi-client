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
	echo "ERROR: Not running as root - aborting"
	exit
fi

#Check for internet connection
if ! ping -w 1 -c 1 8.8.8.8; then
	echo "ERROR: No direct internet connection - aborting"
	exit
fi

#Check for required packages
if ! (which apt-get); then
	echo "ERROR: Missing packages - aborting"
	exit
fi

#Change directory to the script's location
cd "$( dirname "${BASH_SOURCE[0]}" )"

#Make sure our files are here
if ! ( [[ -d configuration ]] && [[ -d linuxclientsetup ]] && [[ -f linuxclientsetup/scripts/client-config ]] ); then
	echo "ERROR: Missing files required for installation - aborting"
	exit
fi

#Last chance to exit
echo "Configuration checks passed!"
echo "This is your last chance to abort:"
echo "Press Ctrl + C to halt the installation..."
echo
echo "Continuing in:"
echo "5 seconds"
sleep 1
echo "4 seconds"
sleep 1
echo "3 seconds"
sleep 1
echo "2 seconds"
sleep 1
echo "1 second"
sleep 1

###################
#Pre-installation configuration
###################

echo "Preparing environment..."
echo "Warning: Do not interrupt the procedure or your system may be in"
echo "         an inconsistent state"

#Set up resolv.conf for reliable DNS
echo "nameserver 8.8.8.8
nameserver 8.8.4.4" > /etc/resolv.conf

#Copy in new APT repositories
find configuration/etc/apt/sources.list.d -mindepth 1 -maxdepth 1 -print0 | xargs -0 cp -f -t /etc/apt/sources.list.d

#Update APT
apt-get update

echo "Preparation finished!"
echo

###################
#Installation
###################

#Install packages
echo "Installing packages..."
apt-get -qy install xfce4 indicator-application-gtk2 indicator-sound-gtk2 indicator-multiload xfce4-datetime-plugin xfce4-indicator-plugin xfce4-screenshooter \
    xfce4-terminal xubuntu-artwork xubuntu-icon-theme thunar-archive-plugin thunar-media-tags-plugin catfish lightdm lightdm-kde-greeter firefox \
    flashplugin-installer thunderbird xul-ext-lightning file-roller wine filezilla krdc wireshark virtualbox geogebra celestia stellarium kcolorchooser \
    libreoffice libreoffice-l10n-en-gb libreoffice-help-en-gb myspell-en-gb mytheus-en-us wbritish rednotebook gedit gedit-plugins scribus kompozer planner \
    freemind ttf-dejavu ttf-mscorefonts-installer tty-freefont dia blender gimp inkscape ardour audacity jackd2 qjackctl a2jmidid hydrogen rosegarden \
    musescore pavucontrol qsynth fluid-soundfont-gm lmms yoshimi lame stopmotion gtk-recordmydesktop openshot vlc codeblocks eclipse glade greenfoot netbeans \
    g++ libboost1.48-all-dev libglew1.6-dev libsfml-dev libgmp-dev libmpfr-dev libncurses5-dev default-jdk liblwjgl-java cifs-utils libpam-mount krb5-user \
    libpam-krb5 libpam-winbind nslcd ntp bleachbit xautolock remastersys-gui yad winbind ubiquity-casper linux-lowlatency gnupg language-pack-en ldap-utils \
    synaptic rubygems

#Remove packages
echo "Removing packages..."
apt-get -qy purge unity avahi-daemon ntpdate mousepad nautilus linux-image-generic linux-headers-generic network-manager resolvconf

#Install git-up
gem install git-up

#Create administrator user
[[ -e /opt/administrator ]] && rm -rf /opt/administrator
if ! useradd -d /opt/administrator -m -U -r; then
	echo "Error in creating administrator user - removing existing user and trying again" >&2
	userdel administrator
	useradd -d /opt/administrator -m -U -r
fi

#Move home directories that currently exist in /home
while IFS=":" read -r username _ _ _ _ home _; do
	if [[ $home =~ ^/home ]]; then
		usermod -d /opt/"$username" -m "$username"
	fi
done < <(getent passwd)

#Clean up /home
find /home -mindepth 1 -delete

#Copy in new configuration (overwrite)
echo "Installing configuration..."
find configuration -mindepth 1 -maxdepth 1 -print0 | xargs -0 cp -f -t /

find linuxclientsetup/admin-skel -mindepth 1 -maxdepth 1 -print0 | xargs -0 cp -f -t ~administrator
chown -R administrator:administrator ~administrator

#Install linuxclientsetup
[[ -e /opt/karoshi ]] && rm -rf /opt/karoshi
mkdir /opt/karoshi
cp -rf linuxclientsetup /opt/karoshi

chmod 755 /opt/karoshi/linuxclientsetup/scripts/*
chmod 755 /opt/karoshi/linuxclientsetup/utilities/*
chmod 644 /opt/karoshi/linuxclientsetup/utilities/*.conf

#Link karoshi-run-script
ln -s karoshi-run-script /usr/bin/karoshi-set-local-password
ln -s karoshi-run-script /usr/bin/karoshi-set-location
ln -s karoshi-run-script /usr/bin/karoshi-set-network
ln -s karoshi-run-script /usr/bin/karoshi-setup
ln -s karoshi-run-script /usr/bin/karoshi-manage-flags
ln -s karoshi-run-script /usr/bin/karoshi-virtualbox-mkdir
ln -s karoshi-run-script /usr/bin/karoshi-pam-wrapper

echo "Installation complete!"

echo "Press Ctrl + C to stop before remastering"
echo
echo "Continuing in:"
echo "5 seconds"
sleep 1
echo "4 seconds"
sleep 1
echo "3 seconds"
sleep 1
echo "2 seconds"
sleep 1
echo "1 second"
sleep 1
echo

###################
#Start remastersys
###################
echo "Beginning remaster..."

#Link karoshi-setup
[[ -d ~administrator/.config/autostart/ ]] || mkdir -p ~administrator/.config/autostart/
ln -s /opt/karoshi/linuxclientsetup/karoshi-setup.desktop ~administrator/.config/autostart/
chown -R administrator:administrator ~administrator

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
sed -i -e "s/^WORKDIR=.*/WORKDIR='$(pwd | sed 's@/@\\/@')'/" \
       -e "s/^EXCLUDES=.*/EXCLUDES='/tmp /mnt'/" \
       -e "s/^LIVEUSER=.*/LIVEUSER='administrator'/" \
	   -e "s/^LIVECDLABEL=.*/LIVECDLABEL='Karoshi Client $iso_version-$iso_arch'/" \
	   -e "s/^CUSTOMISO=.*/CUSTOMISO='karoshi-client-$iso_version-$iso_arch.iso'/" \
	   -e "s/^LIVECDURL=.*/LIVECDURL='$iso_website'/" \
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
remastersys clean
remastersys backup

mv remastersys/karoshi-client-"$iso_version"-"$iso_arch".iso{,.md5} .

echo
echo "Remaster complete!"
echo "ISO Filename: karoshi-client-$iso_version-$iso_arch.iso"
echo "ISO Checksum: karoshi-client-$iso_version-$iso_arch.iso.md5"
echo

###################
#Clean up
###################

rm -rf remastersys

rm -f ~administrator/.config/autostart/karoshi-setup.desktop
#Stop Auto logon
sed -i 's/^autologin/#autologin/' /etc/lightdm/lightdm.conf

echo "Full Karoshi install and remaster complete!"