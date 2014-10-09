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

#Logging
[[ -e /tmp/karoshi-install.log ]] && rm -rf /tmp/karoshi-install.log
touch /tmp/karoshi-install.log
chmod 0644 /tmp/karoshi-install.log

mkfifo /tmp/karoshi-install.fifo.$$
tee /tmp/karoshi-install.log < /tmp/karoshi-install.fifo.$$ &
log_wait_pid=$!
exec &>/tmp/karoshi-install.fifo.$$

function removeRedirection {
	exec 1>&-
	exec 2>&-
	wait $log_wait_pid
	rm /tmp/karoshi-install.fifo.$$
}

trap removeRedirection EXIT

#Usage
function usage {
	echo "Usage:" >&2
	echo "	$0 [--release <version>]" >&2
	echo >&2
	echo " Options:" >&2
	echo "  --release <version> Create release version" >&2
	echo "  --help              Show this help message" >&2
	exit 1
}

#Options
while (( "$#" )); do
	case "$1" in
	--release)
		shift
		release=$1
		;;
	--help)
		usage
		;;
	*)
		echo "Unrecognized option $1" >&2
		usage
		;;
	esac
	shift
done

###################
#Remastersys
###################
function do_remastersys {
	if ! which remastersys; then
		echo "ERROR: No remastersys detected" >&2
		exit 5
	fi

	#Require restart if kernel has changed
	if [[ $(basename "$(readlink -f /vmlinuz)") != vmlinuz-$(uname -r) ]]; then
		echo >&2
		echo "The kernel has been updated" >&2
		echo "Please restart the machine, then run this installation script again to" >&2
		echo "perform a remaster" >&2
		exit 100
	fi
	
	#Modify remastersys with several tweaks
	echo "Performing remastersys tweaks..." >&2
	remastersys_path=$(which remastersys)
	#Check sha1sum of remastersys script
	if [[ $(sha1sum "$remastersys_path") != "d47d49de9a594b4e703a476f87ec5e311e63ce9a  $remastersys_path" ]]; then
		echo "WARNING: $remastersys_path is a different version to the one this" >&2
		echo "         install script was designed for" >&2
		resolved=false
		while ! $resolved; do
			echo -n "Do you want to continue and make the tweaks [y/n]? [n]: " >&2
			read -r input
			case "$input" in
			y*)
				echo "Proceeding with tweaks" >&2
				resolved=true
				;;
			n*|"")
				echo "Aborting remaster" >&2
				resolved=true
				exit 1
				;;
			*)
				echo "$input is not a valid option" >&2
				echo "Choose from 'y' or 'n'" >&2
				;;
			esac
		done
	fi

	cp "$remastersys_path" "$remastersys_path".orig
	#Remove silly LIVEUSER logic
	sed -i '/LIVEUSER="`who -u | grep -v root | cut -d " " -f1| uniq`"/ {
		N
		N
		N
		c
	}' "$remastersys_path"
	#Use proper logic for removing Ubiquity icon from desktop
	sed -i 's@\([[:space:]]*\)rm -rf /home/\*/Desktop/ubiquity\*\.desktop &> /dev/null@\1find "$LIVEHOME"/Desktop -name "ubiquity*.desktop" -delete \&> /dev/null@' "$remastersys_path"

	#Link karoshi-setup
	[[ -d ~administrator/.config/autostart/ ]] || mkdir -p ~administrator/.config/autostart/
	ln -sf /usr/share/applications/karoshi-setup.desktop ~administrator/.config/autostart/
	chown -R administrator:administrator ~administrator

	#Administrator autologin
	cp /etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.orig
	echo "autologin-user=administrator
autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf

	function clean_up {
		echo "Cleaning up..." >&2
		mv "$remastersys_path".orig "$remastersys_path"
		rm -f ~administrator/.config/autostart/karoshi-setup.desktop
		#Stop Auto logon
		mv /etc/lightdm/lightdm.conf.orig /etc/lightdm/lightdm.conf
	}

	trap clean_up SIGINT SIGTERM

	#Determine ISO parameters
	iso_version=${release:-git-$(date +%Y%m%d)}
	iso_website="http://linuxgfx.co.uk/"
	if [[ -f README.md ]] && grep -q "\*\*Website:\*\* " README.md; then
		iso_website=$(sed -n 's/.*\*\*Website:\*\* \(.*\)/\1/p' README.md)
	fi

	#Determine ISO architecture
	iso_arch=$(uname -i)
	[[ $iso_arch == x86_64 ]] && iso_arch=amd64

	echo "ISO Label:   Karoshi Client $iso_version-$iso_arch" >&2
	echo "ISO Website: $iso_website" >&2

	if [[ $release ]]; then
		resolved=false
		while ! $resolved; do
			echo -n "Is this information correct [y/n]?: " >&2
			read -r input
			case "$input" in
			y*)
				echo "Proceeding with remaster" >&2
				resolved=true
				;;
			n*)
				echo "Aborting remaster" >&2
				resolved=true
				exit 1
				;;
			*)
				echo "$input is not a valid option" >&2
				echo "Choose from 'y' or 'n'" >&2
				;;
			esac
		done
	fi

	#Configure remastersys
	sed -i -e "s@^WORKDIR=.*@WORKDIR='/tmp'@" \
		   -e "s@^EXCLUDES=.*@EXCLUDES='/tmp /mnt'@" \
		   -e "s@^LIVEUSER=.*@LIVEUSER='administrator'@" \
		   -e "s@^LIVECDLABEL=.*@LIVECDLABEL='Karoshi Client $iso_version'@" \
		   -e "s@^CUSTOMISO=.*@CUSTOMISO='karoshi-client-$iso_version-$iso_arch.iso'@" \
		   -e "s@^LIVECDURL=.*@LIVECDURL='$iso_website'@" \
		   /etc/remastersys.conf

	#Configure isolinux to use automatic-ubiquity
	sed -i "s@only-ubiquity@automatic-ubiquity@" /etc/remastersys/isolinux/isolinux.cfg.vesamenu

	#Configure boot menu image
	if [[ -e install/splash.png ]]; then
		echo "Found custom splash.png" >&2
		[[ -e /etc/remastersys/isolinux/splash.png ]] && rm -f /etc/remastersys/isolinux/splash.png
		cp install/splash.png /etc/remastersys/isolinux/splash.png
	fi
	#Configure preseed
	if [[ -e install/preseed.cfg ]]; then
		echo "Found custom preseed.cfg" >&2
		[[ -e /etc/remastersys/preseed/custom.seed ]] && rm -f /etc/remastersys/preseed/custom.seed
		cp install/preseed.cfg /etc/remastersys/preseed/custom.seed
	fi

	#Start creating the remaster
	if ! remastersys clean; then
		echo "WARNING: Error in cleaning remastersys working directory (/tmp/remastersys)" >&2
		echo "         Resolve manually, then press Enter to continue" >&2
		read
	fi
	echo "Beginning remaster..." >&2
	if ! remastersys backup; then
		echo "ERROR: remastersys backup failed" >&2
	else
		echo >&2
		echo "Remaster complete!" >&2
		echo "ISO Location: /tmp/remastersys" >&2
		echo "ISO Filename: karoshi-client-$iso_version-$iso_arch.iso" >&2
		echo "ISO Checksum: karoshi-client-$iso_version-$iso_arch.iso.md5" >&2
		echo >&2
	fi

	clean_up
}

###################
#Configuration checks
###################

echo "Performing configuration checks..." >&2

#Check if running as root (duh)
if [[ $EUID -ne 0 ]]; then
	echo >&2
	echo "ERROR: Not running as root" >&2
	exit 1
fi

#Check for internet connection
if ! ping -w 1 -c 1 8.8.8.8; then
	echo >&2
	echo "ERROR: No direct internet connection" >&2
	exit 1
fi

#Check for required packages
if ! (which apt-get); then
	echo >&2
	echo "ERROR: Missing apt-get - is this Ubuntu?" >&2
	exit 1
fi

#Check if logged in as user with home in /home
if [[ ~ =~ ^/home ]]; then
	echo >&2
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

#Check if administrator user already exists and /opt/karoshi already exists
skip_install=false
if getent passwd administrator >/dev/null && [[ -d /opt/karoshi ]] && [[ ~administrator == "/opt/administrator" ]]; then
	echo "You seem to have already installed Karoshi" >&2
	resolved=false
	while ! $resolved; do
		echo -n "Do you want to skip directly to the remaster [y/n]? [n]: " >&2
		read -r input
		case "$input" in
		y*)
			echo "Skipping directly to remaster" >&2
			resolved=true
			skip_install=true
			;;
		n*|"")
			echo "Continuing with normal installation" >&2
			resolved=true
			;;
		*)
			echo "$input is not a valid option" >&2
			echo "Choose from 'y' or 'n'" >&2
			;;
		esac
	done
fi

###################
#Pre-installation configuration
###################

echo "Preparing environment..." >&2
echo "Warning: Do not interrupt the procedure or your system may be in" >&2
echo "         an inconsistent state" >&2

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

set_network "$net_int" "$net_ip" "$net_gw"

if $skip_install; then
	echo "Preparation finished!" >&2
	do_remastersys
	exit 0
fi

#Add new APT repositories
if [[ -f install/apt-repositories ]]; then
	while read -r apt_repo; do
		add-apt-repository -y "$apt_repo"
	done < install/apt-repositories
fi

#Update and upgrade APT
apt-get update
apt-get -y install apt

#Clear all APT holds
apt-mark showhold | xargs -r apt-mark unhold

#Run custom commands
if [[ -f install/pre-commands ]]; then
	bash install/pre-commands
fi

echo "Preparation finished!" >&2

###################
#Package installation/removal
###################

export DEBIAN_FRONTEND=noninteractive

#Configure holds
if [[ -f install/hold-list ]]; then
	echo "Holding back packages..." >&2
	hold_packages=( )
	while read -r pkg; do
		if [[ $pkg != \#* ]] && [[ $pkg ]]; then
			hold_packages+=( "$pkg" )
		fi
	done < install/hold-list
	if [[ $hold_packages ]]; then
		apt-mark hold ${hold_packages[@]}
		err=$?
		if [[ $err -ne 0 ]]; then
			echo >&2
			echo "ERROR: Failed to hold packages - error code from apt-mark: $err" >&2
			exit 2
		fi
	fi
fi

#Install packages
if [[ -f install/install-list ]]; then
	echo "Installing packages..." >&2
	install_packages=( )
	while read -r pkg; do
		if [[ $pkg != \#* ]] && [[ $pkg ]]; then
			install_packages+=( "$pkg" )
		fi
		if [[ $pkg == "#!install" ]]; then
			if [[ $install_packages ]]; then
				apt-get -y --allow-unauthenticated install ${install_packages[@]}
				err=$?
				if [[ $err -ne 0 ]]; then
					echo >&2
					echo "ERROR: Failed to install packages - error code from apt-get: $err" >&2
					exit 2
				fi
			fi
			install_packages=( )
		fi
	done < install/install-list
	if [[ $install_packages ]]; then
		apt-get -y --allow-unauthenticated install ${install_packages[@]}
		err=$?
		if [[ $err -ne 0 ]]; then
			echo >&2
			echo "ERROR: Failed to install packages - error code from apt-get: $err" >&2
			exit 2
		fi
	fi
fi

#Reset holds
apt-mark showhold | xargs -r apt-mark unhold

#Reset network settings in case a package clobbered it
set_network "$net_int" "$net_ip" "$net_gw"

#Remove packages
if [[ -f install/remove-list ]]; then
	echo "Removing packages..." >&2
	remove_packages=( )
	while read -r pkg; do
		if [[ $pkg != \#* ]] && [[ $pkg ]]; then
			remove_packages+=( "$pkg" )
		fi
	done < install/remove-list
	if [[ $remove_packages ]]; then
		apt-get -y purge ${remove_packages[@]}
		err=$?
		if [[ $err -ne 0 ]]; then
			echo >&2
			echo "ERROR: Failed to remove packages - error code from apt-get: $err" >&2
			exit 2
		fi
	fi
fi

#Reset network settings in case a package clobbered it
set_network "$net_int" "$net_ip" "$net_gw"

#Update everything
echo "Updating packages..." >&2
if ! apt-get -y --allow-unauthenticated dist-upgrade; then
	echo >&2
	echo "ERROR: Failed to update packages" >&2
	exit 2
fi

#Remove old kernels
current_kernel=$(readlink -f /vmlinuz)
current_kernel=${current_kernel##*/vmlinuz-}
toremove=( )
for kernel in /boot/vmlinuz-*; do
	kernel=${kernel##*/vmlinuz-}
	if [[ $kernel != "$current_kernel" ]]; then
		toremove+=(
			linux-image-"$kernel"
			linux-headers-"$kernel"
			linux-image-extra-"$kernel"
		)
	fi
done
if [[ $toremove ]]; then
	apt-get -y purge "${toremove[@]}"
fi

#Reset network settings in case a package clobbered it
set_network "$net_int" "$net_ip" "$net_gw"

#Clean up unneeded packages
echo "Autoremoving unneeded packages..." >&2
if ! apt-get -y autoremove; then
	echo >&2
	echo "ERROR: Failed to autoremove packages" >&2
	exit 2
fi

#Reset network settings in case a package clobbered it
set_network "$net_int" "$net_ip" "$net_gw"

###########################
#Non-essential installation
###########################

#Install rubygems
if which gem && [[ -f install/rubygem-list ]]; then
	gems=( $(< install/rubygem-list) )
	if ! gem install ${gems[@]}; then
		echo >&2
		echo "ERROR: Failed to install rubygems" >&2
		echo "       Press Enter to continue" >&2
		read
	fi
fi

################
#Install Karoshi
################

#Remove old PAM modules
pam_modules=( )
while read -r -d $'\0' file; do
	if ! dpkg-query -S "$file"; then
		pam_modules+=( "$(basename "$file")" )
	fi
done < <(find /usr/share/pam-configs -mindepth 1 -print0)
if [[ $pam_modules ]]; then
	pam-auth-update --package --remove "${pam_modules[@]}"
	for file in "${pam_modules[@]}"; do
		echo "Removing orphan PAM config $file"
		rm -rf /usr/share/pam-configs/"$file"
	done
fi

#Remove PAM modules modified in configuration
while read -r -d $'\0' file; do
	config=$(basename "$file")
	if [[ -f /usr/share/pam-configs/$config ]]; then
		echo "Removing PAM config $config - found in new configuration"
		pam-auth-update --package --remove "$config"
		echo "$config" >> /var/lib/pam/seen
	fi
done < <(find configuration/usr/share/pam-configs -mindepth 1 -print0)

#Copy in new configuration (overwrite)
echo "Installing configuration..." >&2
find configuration -mindepth 1 -maxdepth 1 -not -name '*~' -print0 | xargs -r0 cp -rf -t /

#Correct permissions for sudoers.d files
find /etc/sudoers.d -mindepth 1 -maxdepth 1 -execdir chmod -R 0440 {} +

#Reset /etc/network/interfaces to defaults
cat > /etc/network/interfaces << EOF
auto lo
iface lo inet loopback
EOF

echo "Adjusting PAM configuration..." >&2
#Adjust libpam-mount to only run on interactive sessions
pam-auth-update --package --remove libpam-mount
if ! grep -q 'Session-Interactive-Only: yes' /usr/share/pam-configs/libpam-mount; then
	sed -i '/Session-Type:/ a\
Session-Interactive-Only: yes' /usr/share/pam-configs/libpam-mount
fi

#Remove auth modules from PAM to be added back in in setup
pam-auth-update --package --remove sss sss-password karoshi-pre-session karoshi-post-session karoshi-virtualbox-mkdir karoshi-offline-homes
echo "sss
sss-password
karoshi-pre-session
karoshi-post-session
karoshi-virtualbox-mkdir
karoshi-offline-homes" >> /var/lib/pam/seen

#Correct permissions for PAM configuration
find /usr/share/pam-configs -mindepth 1 -maxdepth 1 -execdir chmod 0644 {} +

#Reconfigure PAM
pam-auth-update --package

#Install linuxclientsetup
echo "Installing Karoshi..." >&2
[[ -e /opt/karoshi ]] && rm -rf /opt/karoshi
mkdir /opt/karoshi
cp -rf linuxclientsetup /opt/karoshi
find /opt/karoshi/linuxclientsetup -name '*~' -delete

chmod 755 /opt/karoshi/linuxclientsetup/scripts/*
chmod 755 /opt/karoshi/linuxclientsetup/utilities/*
chmod 644 /opt/karoshi/linuxclientsetup/utilities/*.conf

#Copy LICENCE
[[ -f LICENCE ]] && cp -f LICENCE /opt/karoshi/linuxclientsetup/LICENCE

#Reset existing alternatives
while read -r alternative; do
	alternative=$(basename "$alternative")
	echo "Resetting existing alternative: $alternative"
	while read -r alternative_file; do
		update-alternatives --remove "$alternative" "$alternative_file"
	done < <(update-alternatives --query "$alternative" | sed -n 's/^Alternative: //p')
done < <(find /etc/alternatives -type l -name 'karoshi-*')

#Create links with update-alternatives
if [[ -f install/alternatives-list ]]; then
	while read -r alternative_name link_name _ link_to; do
		if [[ $link_name ]] && [[ $alternative_name ]] && [[ $alternative_name != \#* ]] && [[ -e $link_to ]]; then
			update-alternatives --install "$link_name" "${alternative_name%:}" "$link_to" 20
		fi
	done < install/alternatives-list
fi

#####################
#Users and home areas
#####################

echo "Preparing users and home areas..." >&2

#Create administrator user
[[ -e /opt/administrator ]] && rm -rf /opt/administrator
if ! useradd -d /opt/administrator -m -U -r administrator; then
	echo "Error in creating administrator user - removing existing user and trying again" >&2
	userdel administrator -r
	useradd -d /opt/administrator -m -U -r administrator
	err=$?
	if [[ $err -ne 0 ]]; then
		echo >&2
		echo "ERROR: Unable to create administrator user - error code from useradd: $err" >&2
		exit 4
	fi
fi
if ! [[ -d ~administrator ]]; then
	echo >&2
	echo "ERROR: We have a problem - administrator doesn't have a home directory" >&2
	exit 4
fi
#Set password and other parameters for administrator
chpasswd <<< "administrator:karoshi"
err=$?
if [[ $err -ne 0 ]]; then
	echo >&2
	echo "ERROR: Failed to set password for administrator user" >&2
	echo "       Error code from chpasswd: $err" >&2
	exit 4
fi
usermod -a -G adm,cdrom,sudo,dip,plugdev,lpadmin,sambashare -s /bin/bash administrator
err=$?
if [[ $err -ne 0 ]]; then
	echo >&2
	echo "ERROR: Error setting various paramters to administrator user" >&2
	echo "       Error code from usermod: $err" >&2
	exit 4
fi

echo "Copying necessary admin files to administrator home area..." >&2
find linuxclientsetup/admin-skel -mindepth 1 -maxdepth 1 -print0 | xargs -r0 cp -rf -t ~administrator
chown -R administrator:administrator ~administrator

#Adjust any other users that exist
echo "Adjusting any conflicting users found..." >&2
#Create temporary FD for use inside &0-redirected while loop below
exec 4<&0
while IFS=":" read -r username _ uid gid gecos home shell; do
	if [[ $uid -ge 1000 ]] && [[ $uid -ne 65534 ]]; then
		echo "WARNING: $username has a UID greater than or equal to 1000" >&2
		echo "         Karoshi requires that no local users exist with UIDs above 999" >&2
		echo >&2
		resolved=false
		while ! $resolved; do
			echo -n "Delete user [d] or recreate with lower UID [l]? [d]: " >&2
			read -r usr_input <&4
			case "$usr_input" in
			d*|"")
				echo "Deleting user $username..." >&2
				userdel -r $username
				err=$?
				if [[ $err -eq 0 ]]; then
					IFS=":" read -r _ _ user_group_gid user_group_members < <(getent group $username)
					if [[ $user_group_gid == "$gid" ]]; then
						if ! [[ $user_group_members ]]; then
							echo "Detected empty user group with same name as user" >&2
							groupdel $username
							err=$?
							if [[ $err -eq 0 ]]; then
								echo "Took the liberty of removing the user group" >&2
							else
								echo "WARNING: Removing user group failed - error code from groupdel: $err" >&2
							fi
						else
							echo "WARNING: Detected user group with the same name as user, but it was not empty" >&2
						fi
					fi
					resolved=true
				else
					echo "ERROR: Unable to remove $username - error code from userdel: $err" >&2
				fi
				;;
			l*)
				#Get a list of groups to add the user to later
				groups=( $(id -G $username) )
				echo "Recreating $username with lower UID..." >&2
				userdel $username
				err=$?
				if [[ $err -eq 0 ]]; then
					IFS=":" read -r _ _ user_group_gid user_group_members < <(getent group $username)
					user_group=false
					if [[ $user_group_gid == "$gid" ]]; then
						user_group=true
						if ! [[ $user_group_members ]]; then
							echo "Detected empty user group with same name as user" >&2
							groupdel $username
							err=$?
							if [[ $err -eq 0 ]]; then
								echo "Removed the user group" >&2
								declare -a new_groups
								#Remove old user group from list of groups
								for group in "${groups[@]}"; do
									[[ $group != "$user_group_gid" ]] && new_groups+=($group)
								done
								groups=( "${new_groups[@]}" )
							else
								echo "WARNING: Removing user group failed - error code from groupdel: $err" >&2
							fi
						else
							echo "WARNING: Detected user group with the same name as user, but it was not empty" >&2
						fi
					fi
					
					#Recreate user
					echo "Creating new user with same username $username..." >&2
					if $user_group; then
						useradd -c "$gecos" -d "$home" -G "${groups[@]}" -M -r -s "$shell" -U "$username"
						err=$?
					else
						groups=( "${groups[@]#* }" )
						useradd -c "$gecos" -d "$home" -g "${groups[0]}" -G "${groups[@]}" -M -N -r -s "$shell" "$username"
						err=$?
					fi
					
					if [[ $err -eq 0 ]]; then
						chown -R $username: "$home"
						echo "Successfully recreated $username" >&2
						resolved=true
					else
						echo "ERROR: Failed to recreate user - error code from useradd: $err" >&2
						exit 4
					fi
				else
					echo "ERROR: Unable to remove $username - error code from userdel: $err" >&2
				fi
				;;
			*)
				echo "$usr_input is not a valid option" >&2
				;;
			esac
		done
	fi
	#Deal with home areas that exist in /home
	if [[ $home =~ ^/home ]] && [[ -e $home ]]; then
		echo "Moving home directory for $username..." >&2
		if ! usermod -d /opt/"$username" -m "$username"; then
			echo >&2
			echo "WARNING: Moving home directory for $username has failed" >&2
			echo "         Press Enter to continue" >&2
			read <&4
		fi
	fi
done < <(getent passwd)


#Adjust existing groups
echo "Adjusting any conflicting groups found..." >&2
while IFS=":" read -r groupname _ gid members; do
	if [[ $gid -ge 1000 ]] && [[ $gid -ne 65534 ]]; then
		echo "WARNING: $groupname has a GID greater than or equal to 1000" >&2
		echo "         Karoshi requires that no local groups exist with GIDs above 999" >&2
		echo >&2
		[[ $members ]] || echo "$groupname has no members" >&2
		echo "Press Enter to remove $groupname" >&2
		read <&4
		groupdel $groupname
		err=$?
		if [[ $err -eq 0 ]]; then
			echo "Deleted $groupname successfully" >&2
		else
			echo "ERROR: Failed to delete $groupname - error code from groupdel: $err" >&2
			exit 4
		fi
	fi
done < <(getent group)

exec 4<&-

#Clean up /home
echo "Cleaning up /home..." >&2
find /home -mindepth 1 -delete

#Run custom commands
if [[ -f install/post-commands ]]; then
	bash install/post-commands
fi

echo >&2
echo "Installation of Karoshi Client complete - press Ctrl + C now to finish" >&2
echo "Alternatively, press Enter to continue to remaster the current system" >&2
read

do_remastersys
