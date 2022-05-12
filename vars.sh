#/bin/bash

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
    echo "Unknown disk type - exiting!"
    exit 1
fi

# Set up the device frendly names
export BOOT_DEV="${DEV_P1}"
export SWAP_DEV="${DEV_P2}"
export ROOT_DEV="${DEV_P3}"
export HOME_DEV="${DEV_P4}"

# set up the crypt names
export SWAP_CRYPT_NAME="swap-crypt-p2"
export ROOT_CRYPT_NAME="root-crypt-p3"
export HOME_CRYPT_NAME="home-crypt-p4"

# This can be simple - it's going to be replaced with recovery keys
export PASSPHRASE="password"

# Set the sizes of the 4 partitions
export P1_SIZE="+500M"
export P2_SIZE="+500M"
export P3_SIZE="+15G"
export P4_SIZE="0"    # rest of the disk

export BTRFS_MOUNT_OPTIONS_="-o rw,noatime,noautodefrag,compress=zstd:1,ssd,space_cache=v2,subvol="

# more specifics
export HOSTNAME="alex-fw"
