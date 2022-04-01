#/bin/bash
set -ex

source ./vars.sh
source ./utils.sh

is_mounted "/mnt" || {
    echo "Already mounted, so nothing to do"
    exit 0
}

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
