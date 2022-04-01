#/bin/bash
set -ex

source ./vars.sh
source ./utils.sh

is_mounted "/mnt" && {
    echo "Not mounted, bailing."
    exit 1
}

# relies on the /mnt/etc existing.
if [ ! -d /mnt/etc ]; then
    echo "Nothing is available at /mnt/etc, bailing out"
    exit 0
fi

if [ -e /mnt/etc/luks/crypto_keyfile.bin ]; then
    echo "Keyfile is already set up; bailing!"
    exit 0
fi

mkdir -p /mnt/etc/luks
dd if=/dev/urandom of=/mnt/etc/luks/crypto_keyfile.bin bs=512 count=1
chmod u=rx,go-rwx /mnt/etc/luks
chmod u=r,go-rwx /mnt/etc/luks/crypto_keyfile.bin

echo -n "$PASSPHRASE" | cryptsetup luksAddKey ${DEV_P2} /mnt/etc/luks/crypto_keyfile.bin
echo -n "$PASSPHRASE" | cryptsetup luksAddKey ${DEV_P3} /mnt/etc/luks/crypto_keyfile.bin
echo -n "$PASSPHRASE" | cryptsetup luksAddKey ${DEV_P4} /mnt/etc/luks/crypto_keyfile.bin

