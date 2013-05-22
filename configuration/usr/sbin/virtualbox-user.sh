#!/bin/bash

if [[ $EUID -ne 0 ]]; then
	echo "ERROR: Must be run as root!" >&2
	exit 1
fi
if [ ! "$SUDO_USER" ]; then
	echo "ERROR: Must be run under sudo!" >&2
	exit 1
fi

VIRTUALBOX_PATH="/opt/virtualbox"
USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

if [ ! -d "$VIRTUALBOX_PATH" ]; then
	mkdir -p "$VIRTUALBOX_PATH"
	mkdir -p "$VIRTUALBOX_PATH"/isos
	chmod +t "$VIRTUALBOX_PATH"/isos
fi

if [ ! -d "$VIRTUALBOX_PATH"/users/"$SUDO_USER" ]; then
	mkdir -p "$VIRTUALBOX_PATH"/users/"$SUDO_USER"
	chown -R $SUDO_UID:$SUDO_GID "$VIRTUALBOX_PATH"/users/"$SUDO_USER"
fi

[ -e "$USER_HOME"/.VirtualBox ] || sudo -n -u $SUDO_USER ln -sf "$VIRTUALBOX_PATH"/users/"$SUDO_USER" "$USER_HOME"/.VirtualBox
[ -e "$USER_HOME"/"VirtualBox VMs" ] || sudo -n -u $SUDO_USER ln -sf "$VIRTUALBOX_PATH"/users/"$SUDO_USER" "$USER_HOME"/"VirtualBox VMs"

sudo -n -u $SUDO_USER VirtualBox "$@"
