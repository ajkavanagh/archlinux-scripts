#/bin/bash
set -ex

source ./vars.sh
source ./utils.sh


is_mounted "/mnt" && {
    echo "Not mounted, bailing."
    exit 1
}

# setup the keyboard
echo "KEYMAP=uk" > /mnt/etc/vconsole.conf

# generate the fstab file
cat << EOF > /mnt/etc/fstab
# Static information about the filesystems.
# See fstab(5) for details.

# <file system> <dir> <type> <options> <dump> <pass>
EOF

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
#MODULES="MODULES=(btrfs vmd)"
MODULES="MODULES=(btrfs virtio virtio_blk virtio_pci virtio_net)"
BINARIES="BINARIES=(/usr/bin/btrfs)"
# NOTE: we don't put the LUKS unlock key in the initramfs as it won't be
# encrypted. Instead, the key will be enrolled in the TPM2 and the unified
# kernel will be signed and secure booted.
FILES="FILES=(/etc/crypttab /etc/passwd /etc/shadow)"
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

PRESETS=('arch' 'fallback')

arch_kver="/boot/vmlinuz-linux"
arch_image="/boot/initramfs-linux.img"
arch_efi_image="/boot/EFI/Linux/archlinux-linux.efi"
arch_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"

fallback_kver="/boot/vmlinuz-linux-lts"
fallback_image="/boot/initramfs-linux-lts-fallback.img"
fallback_efi_image="/boot/EFI/Linux/archlinux-linux-lts-fallback.efi"
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
swap_UUID=$(echo "$block_to_uuid" | awk -v pat="$(basename $DEV_P2)" '$0~pat{ print $2 }')
root_UUID=$(echo "$block_to_uuid" | awk -v pat="$(basename $DEV_P3)" '$0~pat{ print $2 }')
home_UUID=$(echo "$block_to_uuid" | awk -v pat="$(basename $DEV_P4)" '$0~pat{ print $2 }')

cmd_line=""
cmd_line="$cmd_line rd.luks.name=${swap_UUID}=swap-crypt-p2"
cmd_line="$cmd_line rd.luks.name=${root_UUID}=root-crypt-p3"
cmd_line="$cmd_line rd.luks.name=${home_UUID}=home-crypt-p4"
cmd_line="$cmd_line rd.luks.options=timeout=30s"
cmd_line="$cmd_line root=/dev/mapper/root-crypt-p3"
cmd_line="$cmd_line rootflags=subvol=@"
cmd_line="$cmd_line rootfstype=btrfs"
#cmd_line="$cmd_line loglevel=3 resume=/dev/mapper/swap-crypt-p2"
#cmd_line="$cmd_line rw bgrt_disable"
cmd_line="$cmd_line rw"

echo $cmd_line > /mnt/etc/kernel/cmdline

# Set up the /mnt/etc/crypttab file
#CRYTPTTAB=/mnt/etc/crypttab
#cat << EOF > $CRYTPTTAB
## <target name>	<source device>		<key file>	<options>
#root-crypt-p3	UUID=${root_UUID}	none	luks
#swap-crypt-p2	UUID=${swap_UUID}	none	luks,swap
#home-crypt-p4	UUID=${home_UUID}	none	luks
#EOF

# Create a boot loader entry:
#LOADER_DIR=/mnt/boot/loader/entries
#LOADER_ENTRY="${LOADER_DIR}/arch.conf"
#mkdir -p "${LOADER_DIR}"
#cat << EOF > $LOADER_ENTRY
#title Arch
#linux /vmlinuz-linux
#initrd /intel-ucode.img
#initrd /initramfs-linux.img
#options rd.luks.name=${root_UUID}=root-crypt-p3 root=/dev/mapper/root-crypt-p3 rootflags=subvol=@ rw
#EOF

# create the options for the boot.
LOADER_DIR="/mnt/boot/loader"
LOADER_CONF="${LOADER_DIR}/loader.conf"
mkdir -p "${LOADER_DIR}"
cat << EOF > $LOADER_CONF
timeout 5
default arch
console-mode 0
EOF

# finalliy regenerate the kernel
mkdir -p /mnt/boot/EFI/Linux
arch-chroot /mnt mkinitcpio -P
arch-chroot /mnt bootctl install --esp-path=/boot
