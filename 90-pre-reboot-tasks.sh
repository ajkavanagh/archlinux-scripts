#!/bin/bash
set -e

source ./vars.sh
source ./utils.sh

# Say where we are.
ln -sf /mnt/usr/share/zoneinfo/Europe/London /mnt/etc/localtime

# sync the clock
arch-chroot /mnt hwclock --systohc

# Set up the locale

sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
sed -i 's/#en_GB.UTF-8/en_GB.UTF-8/' /mnt/etc/locale.gen
sed -i 's/#en_GB /en_GB /' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen

echo "LANG=en_GB.UTF-8" > /mnt/etc/locale.conf

# Configure the hostname
echo "$HOSTNAME" > /mnt/etc/hostname

# Configure the network

cat << EOF > /mnt/etc/hosts

127.0.0.1        localhost
::1              localhost
127.0.1.1        $HOSTNAME
EOF

# set the password for root; this will be changed later!
#arch-chroot /mnt chpasswd root:p

# see if the alex user is created and set the passwd
# arch-chroot /mnt chpassed alex:p
