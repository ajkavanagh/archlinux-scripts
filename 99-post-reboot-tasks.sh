#!/bin/bash
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

# Start the sshd server
# TODO: disable this normally
systemctl enable sshd.service

# Reminder for root password.
echo "!!! Remember to set a root password! - use passwd"
