# Karoshi Client

*Repository for storing scripts and configuration files for Karoshi Client*

- **Maintainer:** Robin McCorkell &lt;rmccorkell@karoshi.org.uk&gt;
- **Website:** http://linuxgfx.co.uk/
- **Documentation:** http://www.linuxgfx.co.uk/karoshi/documentation/wiki/
- **Current stable version:** 2.0
- **Current dev version:** 2.2_rc8

**ISO Syntax:** karoshi-client-&lt;version&gt;-&lt;arch&gt;.iso

**Title Syntax:** Karoshi Client &lt;version&gt;-&lt;arch&gt;

## File list

- **CHECKLIST.md** is a short guide for creating a remaster
- **README.md** is this file
- **configuration/** contains the system configuration
- **linuxclientsetup/** contains the main client-side scripts
- **skel/** contains configuration files for the client, usually placed on the server
- other files are assorted temporary configuration files

## Required packages

These packages need to be installed on the client prior to a remaster

### XFCE

- xfce4
- indicator-application-gtk2
- indicator-sound-gtk2
- indicator-multiload
- xfce4-datetime-plugin
- xfce4-indicator-plugin
- xfce4-screenshooter
- xfce4-terminal
- xubuntu-artwork
- xubuntu-icon-theme
- thunar-archive-plugin
- thunar-media-tags-plugin
- catfish

### General Applications

- lightdm
- lightdm-kde-greeter
- firefox
- flashplugin-installer
- thunderbird
- xul-ext-lightning
- file-roller
- wine
- filezilla
- krdc
- wireshark
- virtualbox
- geogebra
- celestia
- stellarium
- kcolorchooser

### Office Applications

- libreoffice
- libreoffice-l10n-en-gb
- libreoffice-help-en-gb
- myspell-en-gb
- mytheus-en-us
- wbritish
- rednotebook
- gedit
- gedit-plugins
- scribus
- kompozer
- planner
- freemind
- ttf-dejavu
- ttf-mscorefonts-installer
- tty-freefont

### Graphics Applications

- dia
- blender
- gimp
- inkscape

### Audio Applications

- ardour
- audacity
- jackd2
- qjackctl
- a2jmidid
- hydrogen
- rosegarden
- musescore
- pavucontrol
- qsynth
- fluid-soundfont-gm
- lmms
- yoshimi
- lame

### Video Applications

- stopmotion
- gtk-recordmydesktop
- openshot
- vlc

### Development

- codeblocks
- eclipse
- glade
- greenfoot
- netbeans
- g++
- libboost1.48-all-dev
- libglew1.6-dev
- libsfml-dev
- libgmp-dev
- libmpfr-dev
- libncurses5-dev
- default-jdk
- liblwjgl-java

### Utilities

- cifs-utils
- libpam-mount
- krb5-user
- libpam-krb5
- libpam-winbind
- nslcd
- ntp
- bleachbit
- xautolock
- remastersys-gui
- yad
- winbind
- ubiquity-casper
- linux-lowlatency
- gnupg
- language-pack-en
- ldap-utils
- synaptic
- rubygems
- -> git-up
- xmlstarlet
- resolvconf

## Packages to remove

These packages should be **removed** to save disk space or remove conflicts

- unity
- avahi-daemon
- ntpdate
- mousepad
- nautilus
- linux-image-generic
- linux-headers-generic
- network-manager

## Symlinks

Some Karoshi utilities need to be symlinked to karoshi-run-script in /usr/bin so that they can be run using the PATH variable:

- ln -s karoshi-run-script /usr/bin/karoshi-set-local-password
- ln -s karoshi-run-script /usr/bin/karoshi-set-location
- ln -s karoshi-run-script /usr/bin/karoshi-set-network
- ln -s karoshi-run-script /usr/bin/karoshi-setup
- ln -s karoshi-run-script /usr/bin/karoshi-manage-flags
- ln -s karoshi-run-script /usr/bin/karoshi-virtualbox-mkdir
- ln -s karoshi-run-script /usr/bin/karoshi-pam-wrapper
