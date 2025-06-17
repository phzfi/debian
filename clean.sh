#!/bin/bash
suite=${1:-unstable}

chroot_dir=/var/chroot/$suite

echo "cleaning"
echo $chroot_dir

rm reports/* || true
### cleanup
rm debian.tgz

umount /var/chroot/bookworm/proc/
rm -rf $chroot_dir

