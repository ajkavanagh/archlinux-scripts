#/bin/bash
set -ex

source ./vars.sh
source ./utils.sh


is_mounted "/mnt" && {
    echo "Not mounted, bailing."
    exit 1
}

# assumptions: /mnt has to be mounted, and initial pacstrap is done.  Script
# only does things that haven't already been setup.

# vars
MKINITCPIO="/mnt/etc/mkinitcpio.conf"
MKINITCPIO_ORIG="${MKINITCPIO}.orig"

# check if mkinitcpio.conf.orig has been made?
if [ ! -e "$MKINITCPIO_ORIG" ]; then
    cp "$MKINITCPIO" "$MKINITCPIO_ORIG"
fi

# ensure that the MODULES, BINARIES, FILES and HOOKS are set
MODULES="MODULES=(vmd)"
BINARIES="BINARIES=(/usr/bin/btrfs)"
# NOTE: we don't put the LUKS unlock key in the initramfs as it won't be
# encrypted. Instead, the key will be enrolled in the TPM2 and the unified
# kernel will be signed and secure booted.
FILES="FILES=()"
# TODO: this needs modifying to the systemd-boot version and remove the extra
# grub
HOOKS="HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard keymap consolefont fsck grub-btrfs-overlayfs)"

sed -i "/^MODULES=/c $MODULES" $MKINITCPIO
sed -i "/^BINARIES=/c $BINARIES" $MKINITCPIO
sed -i "/^FILES=/c $FILES" $MKINITCPIO
sed -i "/^HOOKS=/c $HOOKS" $MKINITCPIO
