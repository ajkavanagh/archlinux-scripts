#!/bin/bash
set -e

source ./vars.sh
source ./utils.sh

if [ "$USER" != "root" ]; then
    echo "This script must be run as root"
    exit 1
fi

### Description
#
# Set up the secure boot on the device.
#
# !!! This must be run on the device, and not from pacstrap, as it will modify
# the EFI vars on the device; I'm not sure they will be the 'same' vars when
# booted from the archiso (and that would take extra testing).  Besides, it's
# good to start doing these things from within the actual runtime.

# We can use $PASSWORD to provide the password to systemd-cryptenroll and also
# then extract the recovery key to a file.

# Stages:
#
# 1. setup up sbctl and set up the keys.
# 2. sign the various parts of the kernel
# 3. Set up the software to ensure that kernels continue to get signed and the
# hook to ensure new kernels get signed.
# 4. Set up recovery keys, enroll the 3 partitions and and then wipe the
# insecure password; ensure the recovery keys end up in a file. Tell the user
# to copy the file!

# Okay, let's get started:
# 1. Setup sbctl and the keys
pacman -Sy sbctl
sbctl status
if [ -f /usr/share/secureboot/keys/db/db.pem ]; then
    echo "sbctl keys already created."
else
    sbctl create-keys
    sbctl verify
    #if [[ "$VIRT_IS" == "kvm" ]]; then
    if [ is_kvm ]; then
        chattr -i /sys/firmware/efi/efivars/PK-* ||:
        chattr -i /sys/firmware/efi/efivars/KEK-* ||:
        chattr -i /sys/firmware/efi/efivars/db-* ||:
        sbctl enroll-keys --yes-this-might-brick-my-machine
    else
        sbctl enroll-keys
    fi
fi

echo "Keys db is: /usr/share/secureboot/keys/db/"
ls /usr/share/secureboot/keys/db/

# 2. sign the various parts of the kernel
cat > /etc/dracut.conf.d/50-secure-boot.conf <<EOF
uefi_secureboot_cert="/usr/share/secureboot/keys/db/db.pem"
uefi_secureboot_key="/usr/share/secureboot/keys/db/db.key"
EOF

# Sign the systemd-bootx64 file.
[ -f /usr/lib/systemd/boot/efi/systemd-bootx64.efi ] && sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed /usr/lib/systemd/boot/efi/systemd-bootx64.efi
[ -f /usr/lib/fwupd/efi/fwupdx64.efi ] && sbctl sign -s -o /usr/lib/fwupd/efi/fwupdx64.efi.signed /usr/lib/fwupd/efi/fwupdx64.efi
bootctl install

# 3. Set up the software to ensure that kernels continue to get signed and the
# hook to ensure new kernels get signed.
cat > /etc/dracut.conf.d/50-tpm2.conf <<EOF
add_dracutmodules+=" tpm2-tss "
EOF

# Re-generate the initramfs for booting
pacman -Sy tpm2-tools
dracut -f --uefi --regenerate-all


# 4. Enroll the keys, etc.
RECOVERY_KEYS=/root/recovery_keys.txt
echo "Paritions and recovery keys:" > ${RECOVERY_KEYS}

for _dev in ${SWAP_DEV} ${ROOT_DEV} ${HOME_DEV}; do
    echo "Doing ${_dev} ..."
    recovery_key=$(PASSWORD="${PASSPHRASE}" systemd-cryptenroll ${_dev} --wipe-slot="recovery" --recovery-key)
    echo "${_dev} ${recovery_key}" >> ${RECOVERY_KEYS}
    PASSWORD="${PASSPHRASE}" systemd-cryptenroll ${_dev} --wipe-slot="tpm2" --tpm2-device=auto
done

echo "Make sure you grab the recovery keys from '${RECOVERY_KEYS}' !!!"
cat $RECOVERY_KEYS
