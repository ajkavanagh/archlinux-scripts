# Secure boot testing with libvirt

In order to test the secure boot setup scripts it's useful to be able to test it on virtual machines.  But in order to do that, we have to enable EFI/TPM2 on the libvirt machine.  And in order to do that we need swtpm-tools.

These notes are for Ubuntu 20.04 (focal), which is a bit of a shame as 22.04 (jammy) has just come out (May 2022).

For focal we need to use a PPA from smoser, and install it:

```sh
$ sudo add-apt-repository ppa:smoser/swtpm
$ sudo apt update
$ sudo apt install swtpm-tools
```

Then we need to ensure that a TPM2 device is added to the hardware of the libvirt machine.  For the machine I had, I added it using the "Add Hardware" button, and seleted the default "TPM" device.  Then rebooted the virtual machine.

I then ran into a permissions error, where the vitual machine wouldn't start. This was solved with:

```sh
$ sudo chown tss /var/lib/swtpm-localca/
```

The vitual machine then started.  Howeve, when I got to the enroll keys stage, I ran into an additional issue with permissions on the EFI vars.  This was solved with (inside the virtual machine):

```sh
chattr -i /sys/firmware/efi/efivars/PK-8be4df61-93ca-11d2-aa0d-00e098032b8c
chattr -i /sys/firmware/efi/efivars/KEK-8be4df61-93ca-11d2-aa0d-00e098032b8c
chattr -i /sys/firmware/efi/efivars/db-d719b2cb-3d3a-4596-a3bc-dad00e67656f
```

Note: the UUID following the `PK`, `KEK` and `db` will be different for each virtual machine.

Finally, to actually enroll the keys, it was necessay to use the `--yes-this-might-brick-my-machine` flag:

```sh
# sbctl enroll-keys --yes-this-might-brick-my-machine
```

I suspect this is because swtpm-tools isn't 'quite' right, and thus sbctl doesn't fully support it.  However, the enrolling of keys did work, and I've built these requirements into the scripts for the setup of Archlinux (which uses sbctl for the enrollment of keys).

