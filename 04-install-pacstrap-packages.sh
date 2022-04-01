#/bin/bash
set -ex

source ./vars.sh
source ./utils.sh


is_mounted "/mnt" && {
    echo "Not mounted, bailing."
    exit 1
}

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
