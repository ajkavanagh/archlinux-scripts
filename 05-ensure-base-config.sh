#/bin/bash
set -ex

source ./vars.sh
source ./utils.sh


is_mounted "/mnt" && {
    echo "Not mounted, bailing."
    exit 1
}

# generate the fstab file
genfstab -U /mnt >> /mnt/etc/fstab

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
#MODULES="MODULES=(vmd)"
MODULES="MODULES=(virtio virtio_blk virtio_pci virtio_net)"
BINARIES="BINARIES=(/usr/bin/btrfs)"
# NOTE: we don't put the LUKS unlock key in the initramfs as it won't be
# encrypted. Instead, the key will be enrolled in the TPM2 and the unified
# kernel will be signed and secure booted.
FILES="FILES=()"
# TODO: this needs modifying to the systemd-boot version and remove the extra
# grub
#HOOKS="HOOKS=(base udev autodetect modconf block encrypt filesystems keyboard keymap consolefont fsck)"
HOOKS="HOOKS=(base systemd keyboard autodetect sd-vconsole modconf block sd-encrypt filesystems fsck)"

sed -i "/^MODULES=/c $MODULES" $MKINITCPIO
sed -i "/^BINARIES=/c $BINARIES" $MKINITCPIO
sed -i "/^FILES=/c $FILES" $MKINITCPIO
sed -i "/^HOOKS=/c $HOOKS" $MKINITCPIO

# Set up the unified kernel stuff
# We're going to use mkinitcpio as its' the default.  Some people use dracut;
# I'd rathe se mkinitcpio 'because'!


LINUX_PRESET="/mnt/etc/mkinitcpio.d/linux.preset"
LINUX_PRESET_BACKUP="${LINUX_PRESET}.orig"

if [ ! -e "$LINUX_PRESET_BACKUP" ]; then
    cp "$LINUX_PRESET" "$LINUX_PRESET_BACKUP"
fi

cat << EOF > $LINUX_PRESET
/etc/mkinitcpio.d/linux.preset

ALL_config="/etc/mkinitcpio.conf"
ALL_microcode=(/boot/*-ucode.img)

PRESETS=('default' 'fallback')

default_kver="/boot/vmlinuz-linux"
default_image="/boot/initramfs-linux.img"
default_efi_image="/boot/efi/EFI/Linux/archlinux-linux.efi"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"

fallback_kver="/boot/vmlinuz-linux-lts"
fallback_image="/boot/initramfs-linux-lts-fallback.img"
fallback_efi_image="/boot/efi/EFI/Linux/archlinux-linux-lts-fallback.efi"
fallback_options="-S autodetect --splash /usr/share/systemd/bootctl/splash-arch.bmp"
EOF

# Set the command line options (for UEFI unikenel builds)
# need to assemble the swap-crypt-p2, root-crypt-p3 and home-crypt-p4 UUIDs
# as rd.luks.name=<UUID>=boot-crypt-p2
#    rd.luks.name=<UUID>=root-crypt-p3
#    rd.luks.name=<UUID>=home-crypt-p4
#
# we don't put rd.luks.key in here (TODO) as that's coming from secure boot.
#
# lsblk -f -oNAME,UUID -r <-- gives the name and UUID as:

# NAME UUID
# loop0
# sr0 2022-03-01-15-50-40-00
# vda
# vda1 2D57-FD6A
# vda2 848bd3e2-6c73-43b2-975d-de59b81ea5b1
# swap-crypt-p2 2cb64ba2-4cc7-4e1a-bec3-820589a05dff
# vda3 c0551d67-724b-4a7e-bb4f-4deccef0d2b8
# root-crypt-p3 0446793c-e4f1-48d3-97a1-ae5abe12ce1d
# vda4 6cc2ec4b-75f0-4c54-aeab-e90d17e139ee
# home-crypt-p4 971990eb-fb4e-4149-801c-3a71e0056b65

block_to_uuid=$(lsblk -f -oNAME,UUID -r)
swap_UUID=$(echo "$block_to_uuid" | awk '/swap-crypt-p2/{ print $2 }')
root_UUID=$(echo "$block_to_uuid" | awk '/root-crypt-p3/{ print $2 }')
home_UUID=$(echo "$block_to_uuid" | awk '/home-crypt-p4/{ print $2 }')

cmd_line=""
cmd_line="$cmd_line rd.luks.name=${swap_UUID}=swap-crypt-p2"
cmd_line="$cmd_line rd.luks.name=${root_UUID}=root-crypt-p3"
cmd_line="$cmd_line rd.luks.name=${home_UUID}=home-crypt-p4"
cmd_line="$cmd_line rd.luks.options=timeout=30s"
cmd_line="$cmd_line root=/dev/mapper/root-crypt-p3"
cmd_line="$cmd_line rootfstype=btrfs"
#cmd_line="$cmd_line loglevel=3 resume=/dev/mapper/swap-crypt-p2"
#cmd_line="$cmd_line rw bgrt_disable"
cmd_line="$cmd_line rw"

echo $cmd_line > /mnt/etc/kernel/cmdline

# finalliy regenerate the kernel
mkdir -p /mnt/boot/efi/EFI/Linux
arch-chroot /mnt mkinitcpio -P
arch-chroot /mnt bootctl install --esp-path=/boot/efi
