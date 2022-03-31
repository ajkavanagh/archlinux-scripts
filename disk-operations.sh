#/bin/bash
set -ex

# TODO: set up some vars - put these in a separate, source-able script
if [ -e /dev/vda ]; then
    export DEVICE="/dev/vda"
    export DEV_P1="${DEVICE}1"
    export DEV_P2="${DEVICE}2"
    export DEV_P3="${DEVICE}3"
    export DEV_P4="${DEVICE}4"
elif [ -e /dev/sda ]; then
    export DEVICE="/dev/sda"
    export DEV_P1="${DEVICE}1"
    export DEV_P2="${DEVICE}2"
    export DEV_P3="${DEVICE}3"
    export DEV_P4="${DEVICE}4"
elif [ -e /dev/nvme0n1 ]; then
    export DEVICE="/dev/nvme0n1"
    export DEV_P1="${DEVICE}p1"
    export DEV_P2="${DEVICE}p2"
    export DEV_P3="${DEVICE}p3"
    export DEV_P4="${DEVICE}p4"
else
fi

export PASSPHRASE='password'

## Ask if you are sure. Question text is in ${1}
# Note, if the DEFAULT_TO_YES environment variable is set to 'yes|y', then assume the response is yes
# returns _yes=1 if yes, else _yes is unset
function are_you_sure {
    unset _yes
    local _default_yes
    _default_yes=${DEFAULT_TO_YES,,}    # to lowercase
    if [[ "$_default_yes" =~ ^(yes|y)$ ]]; then
        _yes=1
    else
        read -r -p "${1} [y/N]:" response
        response=${response,,}          # to lower case
        if [[ "$response" =~ ^(yes|y)$ ]]; then
            _yes=1
        fi
    fi
}

# TODO: disk creation script starts here

are_you_sure "Are you sure - this will recreate the partition table; delete it and continue (y) or exit (N)"

# patition the disk, zap it first
sgdisk -Z $DEVICE
# p1 is the EFI partion, 1GB
sgdisk -n0:0:+1G -t0:ef02 -c0:"EFI Boot" $DEVICE
# p2 is the LUKS encypted swap partion, 32GB
sgdisk -n0:0:+32G -t0:8309 -c0:"LUKS Swap" $DEVICE
# p3 is the LUKS encypted root partion, 100GB
sgdisk -n0:0:+100G -t0:8309 -c0:"LUKS Root" $DEVICE
# p4 is the LUKS encypted home partion, remaining disk -50G
sgdisk -n0:0:-50G -t0:8309 -c0:"LUKS Home" $DEVICE
# NOTE: 50GB is left at the end of the disk for trim to have plenty of room

# Now luks encrypt the partitions.
echo -n "$PASSPHRASE" | cryptsetup --type luks2 luksFormat ${DEV_P2}
echo -n "$PASSPHRASE" | cryptsetup --type luks2 luksFormat ${DEV_P3}
echo -n "$PASSPHRASE" | cryptsetup --type luks2 luksFormat ${DEV_P4}

# Now open the LUKS partitions
echo -n "$PASSPHRASE" | cryptsetup open ${DEV_P2} swap-crypt-p2
echo -n "$PASSPHRASE" | cryptsetup open ${DEV_P3} root-crypt-p3
echo -n "$PASSPHRASE" | cryptsetup open ${DEV_P4} home-crypt-p4

# Finally, let's format
mkfs.fat -F32 ${DEV_P1}
mkswap /dev/mapper/swap-crypt-p2
mkfs.btrfs /dev/mapper/root-crypt-p3
mkfs.btrfs /dev/mapper/home-crypt-p4

# now to setup the subvolumes for the root and home partitions.
# first the root partition
BTRFS_MOUNT_OPTIONS_="-o rw,noatime,noautodefrag,compress=zstd:1,ssd,space_cache=v2,subvol="

# first mount the root to /mnt
mount /dev/mapper/root-crypt-p3 /mnt
(
    cd /mnt
    btrfs subvolume create @
    btrfs subvolume create @pkg
    btrfs subvolume create @snapshots
    btrfs subvolume create @var_log
    btrfs subvolume create @tmp
    btrfs subvolume create @srv
)
# unmount root after creating the subvolumes
umount /mnt
# now create all the mount points in the '@' subvolume after mounting the '@'
# volume to /mnt
mount ${BTRFS_MOUNT_OPTIONS_}@ /dev/mapper/root-crypt-p3 /mnt
# Then create all the mount points inside that subvolume:
mkdir -p /mnt/{/boot/efi,home,var/cache/pacman/pkg,var/log,tmp,srv,.snapshots}
umount /mnt

# create the /home @ btrfs subvolume
mount /dev/home-crypt-p4 /mnt
(
    cd /mnt
    btrfs subvolume create @
)
umount /mnt

# TODO: NEW script here!

BTRFS_MOUNT_OPTIONS_="-o rw,noatime,noautodefrag,compress=zstd:1,ssd,space_cache=v2,subvol="
# Mount the '@' subvolume to /mnt
mount ${BTRFS_MOUNT_OPTIONS_}@ /dev/mapper/root-crypt-p3 /mnt
# mount the relavent subvolumes to their mount points:
mount ${BTRFS_MOUNT_OPTIONS_}@pkg /dev/mapper/root-crypt-p3 /mnt/var/cache/pacman/pkg
mount ${BTRFS_MOUNT_OPTIONS_}@var_log /dev/mapper/root-crypt-p3 /mnt/var/log
mount ${BTRFS_MOUNT_OPTIONS_}@tmp /dev/mapper/root-crypt-p3 /mnt/tmp
mount ${BTRFS_MOUNT_OPTIONS_}@srv /dev/mapper/root-crypt-p3 /mnt/srv
mount ${BTRFS_MOUNT_OPTIONS_}@snapshots /dev/mapper/root-crypt-p3 /mnt/.snapshots

# mount the efi partition in
mount ${DEV_P1} /mnt/boot/efi

# mount the btrfs into /home
mount ${BTRFS_MOUNT_OPTIONS_}@ /dev/mapper/home-crypt-p4 /mnt/home

# TODO: NEW script here - base installation of packages

# Now with the normal installation (but with extra btrfs packages)
# base
# TODO: this mentions grub, but we are not using it.
pacstrap /mnt base linux linux-firmware cryptsetup btrfs-progs grub \
    grub-btrfs intel-ucode dosfstools efibootmgr e2fsprogs \
    e2fsprogs man-db man-pages texinfo efibootmgr
# networking
pacstrap /mnt wpa_supplicant wireless_tools netctl dialog networkmanager
# editors
pacstrap /mnt neovim vim
# extras
pacstrap /mnt base-devel gptfdisk util-linux
# laptop extras
pacstrap /mnt tlp powertop

# TODO: NEW script here - LUKS key for unlocking disks

mkdir -p /mnt/etc/luks
dd if=/dev/urandom of=/mnt/etc/luks/crypto_keyfile.bin bs=512 count=1
chmod u=rx,go-rwx /mnt/etc/luks
chmod u=r,go-rwx /mnt/etc/luks/crypto_keyfile.bin

# Add the luks keys to the devices:

echo -n "$PASSPHRASE" | cryptsetup luksAddKey ${DEV_P2} /mnt/etc/luks/crypto_keyfile.bin
echo -n "$PASSPHRASE" | cryptsetup luksAddKey ${DEV_P3} /mnt/etc/luks/crypto_keyfile.bin
echo -n "$PASSPHRASE" | cryptsetup luksAddKey ${DEV_P4} /mnt/etc/luks/crypto_keyfile.bin

# TODO: NEW script here - initial setup of the arch-root
# assumptions: /mnt has to be mounted, and initial pacstrap is done.  Script
# only does things that haven't already been setup.

# vars
MKINITCPIO="/etc/mkinitcpio.conf"
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

sed -i "s/^MODULES=/c $MODULES" $MKINITCPIO
sed -i "s/^BINARIES=/c $BINARIES" $MKINITCPIO
sed -i "s/^FILES=/c $FILES" $MKINITCPIO
sed -i "s/^HOOKS=/c $HOOKS" $MKINITCPIO

# TODO: work out the systemd boot stuff - sans encryption
