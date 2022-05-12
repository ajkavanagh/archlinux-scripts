#/bin/bash
set -ex

source ./vars.sh
source ./utils.sh

# disk creation script starts here

are_you_sure "Are you sure - this will recreate the partition table; delete it and continue (y) or exit (N)"
if [[ -z "$_yes" ]]; then
    echo "Bailing out!"
    exit 1
fi

# patition the disk, zap it first
sgdisk -Z $DEVICE
# p1 is the EFI partion, 1GB
sgdisk -n0:0:${P1_SIZE} -t0:ef00 -c0:"EFI Boot" $DEVICE
# p2 is the LUKS encypted swap partion, 32GB  - note 8200 is swap partition
sgdisk -n0:0:${P2_SIZE} -t0:8309 -c0:"LUKS Swap" $DEVICE
# p3 is the LUKS encypted root partion, 100GB - note 8304 is root partition
sgdisk -n0:0:${P3_SIZE} -t0:8304 -c0:"LUKS Root" $DEVICE
# p4 is the LUKS encypted home partion, remaining disk -50G
sgdisk -n0:0:${P4_SIZE} -t0:8309 -c0:"LUKS Home" $DEVICE
# NOTE: 50GB is left at the end of the disk for trim to have plenty of room

# Now luks encrypt the partitions.
# first wipe the partitions:
dd if=/dev/zero of=${DEV_P2} bs=1M count=10
dd if=/dev/zero of=${DEV_P3} bs=1M count=10
dd if=/dev/zero of=${DEV_P4} bs=1M count=10
# then set them up
echo -n "$PASSPHRASE" | cryptsetup --cipher aes-xts-plain64 --hash sha512 --use-random --type luks2 luksFormat ${DEV_P2}
echo -n "$PASSPHRASE" | cryptsetup --cipher aes-xts-plain64 --hash sha512 --use-random --type luks2 luksFormat ${DEV_P3}
echo -n "$PASSPHRASE" | cryptsetup --cipher aes-xts-plain64 --hash sha512 --use-random --type luks2 luksFormat ${DEV_P4}

# Now open the LUKS partitions
echo -n "$PASSPHRASE" | cryptsetup open ${DEV_P2} ${SWAP_CRYPT_NAME}
echo -n "$PASSPHRASE" | cryptsetup open ${DEV_P3} ${ROOT_CRYPT_NAME}
echo -n "$PASSPHRASE" | cryptsetup open ${DEV_P4} ${HOME_CRYPT_NAME}

# Finally, let's format
mkfs.fat -F32 ${DEV_P1}
mkswap /dev/mapper/${SWAP_CRYPT_NAME}
mkfs.btrfs /dev/mapper/${ROOT_CRYPT_NAME}
mkfs.btrfs /dev/mapper/${HOME_CRYPT_NAME}

# now to setup the subvolumes for the root and home partitions.
# first the root partition
mount /dev/mapper/${ROOT_CRYPT_NAME} /mnt
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
mount ${BTRFS_MOUNT_OPTIONS_}@ /dev/mapper/${ROOT_CRYPT_NAME} /mnt
# Then create all the mount points inside that subvolume:
mkdir -p /mnt/{boot,home,var/cache/pacman/pkg,var/log,tmp,srv,.snapshots}
umount /mnt

# create the /home @ btrfs subvolume
mount /dev/mapper/${HOME_CRYPT_NAME} /mnt
(
    cd /mnt
    btrfs subvolume create @
)
umount /mnt
