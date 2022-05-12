#!/bin/bash

# This script assumes/checks that the target file system is mounted at the /mnt
# directory point so that the files can be copied over.


set -ex

source ./vars.sh
source ./utils.sh

is_mounted "/mnt" && {
    echo "Not mounted, so can't do anything."
    exit 0
}

echo "Copying all configuation scripts to the /mnt/root" directory
mkdir -p /mnt/root/framework-arch-setup/
cp -pr * /mnt/root/framework-arch-setup/
