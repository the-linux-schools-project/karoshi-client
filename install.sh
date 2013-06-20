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
	exit
fi

#Check for internet connection
if ! ping -w 1 -c 1 8.8.8.8; then
	echo "ERROR: No direct internet connection - aborting" >&2
	exit
fi

#Check for required packages
if ! (which apt-get); then
	echo "ERROR: Missing packages - aborting" >&2
	exit
fi

#Change directory to the script's location
cd "$( dirname "${BASH_SOURCE[0]}" )"

#Make sure our files are here
if ! ( [[ -d configuration ]] && [[ -d linuxclientsetup ]] && [[ -f linuxclientsetup/scripts/client_config ]] ); then
	echo "ERROR: Missing files required for installation - aborting" >&2
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
apt-get -qy purge unity avahi-daemon ntpdate mousepad nautilus linux-image-generic linux-headers-generic network-manager

#Install git-up
gem install git-up

#Copy in new configuration (overwrite)
echo "Installing configuration..."
find configuration -mindepth 1 -maxdepth 1 -print0 | xargs -0 cp -f -t /

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

#Install linuxclientsetup
[[ -e /opt/karoshi ]] && rm -rf /opt/karoshi
mkdir /opt/karoshi
cp -rf linuxclientsetup /opt/karoshi

chmod 755 /opt/karoshi/linuxclientsetup/scripts/*
chmod 755 /opt/karoshi/linuxclientsetup/utilities/*
chmod 644 /opt/karoshi/linuxclientsetup/utilities/*.conf

echo "Installation complete!"
echo

###################
#Start remastersys
###################

#Link karoshi-setup
[[ -d /opt/administrator/.config/autostart/ ]] || mkdir -p /opt/administrator/.config/autostart/
ln -s /opt/karoshi/linuxclientsetup/karoshi-setup.desktop /opt/administrator/.config/autostart/
