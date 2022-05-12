#!/bin/bash
if [ "$USER" != "root" ]; then
    echo "This script must be run as root"
    exit 1
fi

set -e

source ./vars.sh
source ./utils.sh

## Configure fstrim -- requires util-linux installed earlier
# This runs trim once a week.
systemctl enable fstrim.timer

## Configure tlp -- requires 'tlp' package installed earlier
systemctl enable tlp.service
systemctl start tlp.service

# Sync the time using ntp.
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

# Ensure that we have networking
systemctl enable NetworkManager
systemctl start NetworkManager

# Start the sshd server
# TODO: disable this normally
systemctl enable sshd.service

# Reminder for root password.
echo "!!! Remember to set a root password! - use passwd"
