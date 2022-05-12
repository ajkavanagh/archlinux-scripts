#!/bin/bash
set -e

source ./vars.sh
source ./utils.sh

if [ "$USER" != "root" ]; then
    echo "This script must be run as root"
    exit 1
fi

are_you_sure "Are you sure - this will remove the passphrase; have you got the recovery keys (y) or exit (N)"
if [[ -z "$_yes" ]]; then
    echo "Bailing out!"
    exit 1
fi

echo "Wiping passphrases."
PASSWORD="${PASSPHASE}" systemd-cryptenroll ${SWAP_DEV} --wipe-slot="password"
PASSWORD="${PASSPHASE}" systemd-cryptenroll ${ROOT_DEV} --wipe-slot="password"
PASSWORD="${PASSPHASE}" systemd-cryptenroll ${HOME_DEV} --wipe-slot="password"
echo "Done."
