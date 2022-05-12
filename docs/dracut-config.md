# Understanding dracut

Switching from mkinitcpio to dracut.  Dracut is used in lots of other distributions
and it is probably better maintained.  However, the main thing, is that it can
produce a unikernel without producing the other initramfs; this makes it a
little quicker and also use slightly less diskspace.

The main issues are that the configuration is completely different and requires
a few hooks/packages to ensure that updates to linux, linux-lts and modules
do actually result in the updates of the initramfs.

Basically, I just need to get on with it; one issue is wanting to try NixOS.
