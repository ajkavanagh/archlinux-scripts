#/bin/bash
set -e

source ./vars.sh
source ./utils.sh


is_mounted "/mnt" && {
    echo "Not mounted, bailing."
    exit 1
}

# Now with the normal installation (but with extra btrfs packages)
# base
declare -a groups=(
    base-devel
)

# TODO: this mentions grub, but we are not using it.
declare -a pkgs=(
    base
    linux
    linux-firmware
    cryptsetup
    btrfs-progs
    grub
    grub-btrfs
    intel-ucode
    dosfstools
    efibootmgr
    e2fsprogs
    man-db
    man-pages
    texinfo
    efibootmgr
    wpa_supplicant
    wireless_tools
    netctl
    dialog
    networkmanager
    neovim
    vim
    gptfdisk
    util-linux
    tlp
    powertop
)

install_pkgs=""
for pkg in "${pkgs[@]}"
do
    echo "Looking at $pkg"
    # or do whatever with individual element of the array
    arch-chroot /mnt pacman -Q $pkg || {
        echo "add $pkg"
        install_pkgs="$install_pkgs $pkg"
    }
done

if [[ -n "$install_pkgs" ]]; then
    echo "Need to install:"
    echo $install_pkgs
    pacstrap /mnt $install_pkgs
fi

# now looks at the groups
install_groups=""
for group in "${groups[@]}"; do
    echo "Looking at group $group"
    arch-chroot /mnt pacman -Qg $group || {
        echo "add group $group"
        install_groups="$install_groups $group"
    }
done

if [[ -n "$install_groups" ]]; then
    echo "Installing groups:"
    echo $install_groups
    pacstrap /mnt $install_groups
fi
