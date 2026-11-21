#!/bin/bash
suite=${1:-bookworm}

echo "cleaning"

rm reports/* || true

### cleanup
rm -f debian.tgz
rm -f debian-*.tgz

for arch in i386 amd64; do
  chroot_dir=/var/chroot/$suite-$arch
  echo $chroot_dir
  if [ -d $chroot_dir/proc ]; then
    mountpoint -q $chroot_dir/proc && umount $chroot_dir/proc
  fi
  rm -rf $chroot_dir
done
