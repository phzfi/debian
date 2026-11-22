#!/bin/bash
suite=${1:-bookworm}

echo "cleaning"

rm reports/* || true

### cleanup
rm -f debian.tgz
rm -f debian-*.tgz

### the per-architecture chroots created by build.sh (plus the legacy
### "$suite" name from the single-arch builds); glob-based so new
### architectures in build.sh's arch_list are cleaned up automatically
for chroot_dir in /var/chroot/$suite /var/chroot/$suite-*; do
  [ -d $chroot_dir ] || continue
  echo $chroot_dir
  if [ -d $chroot_dir/proc ]; then
    mountpoint -q $chroot_dir/proc && umount $chroot_dir/proc
  fi
  rm -rf $chroot_dir
done
