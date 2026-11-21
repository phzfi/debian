#!/bin/bash -ex
### Build docker images for phzfi/debian for the i386 and amd64 architectures.
### The images are published as per-architecture tags and combined into
### multi-arch manifest lists (see end of this script).

# debug prints...

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
REPO_DIR=$( cd -- "$SCRIPT_DIR/.." &> /dev/null && pwd )

suite=${1:-bookworm}
VERSION=$2
USER=$3
PASSWORD=$4

if [ -z "$VERSION" ]; then
  echo "Usage: ./build.sh <suite> <version> <user> <password>, e.g. ./build.sh bookworm latest docker_hub_user docker_hub_password"
  exit 1
fi
if [ -z "$USER" ]; then
  echo "Usage: ./build.sh <suite> <version> <user> <password>, e.g. ./build.sh bookworm latest docker_hub_user docker_hub_password"
  exit 1
fi
if [ -z "$PASSWORD" ]; then
  echo "Usage: ./build.sh <suite> <version> <user> <password>, e.g. ./build.sh bookworm latest docker_hub_user docker_hub_password"
  exit 1
fi

#login to docker hub
docker login -u $USER -p $PASSWORD

### settings
arch_list="i386 amd64"
apt_mirror="https://deb.debian.org/debian/"
docker_image="phzfi/debian:$suite-$VERSION"
LATEST="phzfi/debian:$suite-latest"

# Verify tools
TEST=`which debootstrap |wc -l`
if test $TEST -eq 0; then
    echo "FAIL: Required tool debootstrap is missing"
    exit 1
fi
TEST=`which schroot |wc -l`
if test $TEST -eq 0; then
    echo "FAIL: Required tool schroot is missing"
    exit 1
fi

###Clean
if [ -f $SCRIPT_DIR/clean.sh ]; then
  $SCRIPT_DIR/clean.sh $suite
elif [ -f $SCRIPT_DIR/../clean.sh  ]; then
  $SCRIPT_DIR/../clean.sh $suite
elif [ -f /vagrant/clean.sh  ]; then
  /vagrant/docker/clean.sh $suite
elif [ -f /vagrant/docker/clean.sh  ]; then
  /vagrant/docker/clean.sh $suite
else
  echo "FAIL: cleanup failed. Exiting."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
# use the BuildKit backend so --platform works on the cross-architecture build
export DOCKER_BUILDKIT=1

### build each architecture
for arch in $arch_list; do
  chroot_dir="/var/chroot/$suite-$arch"
  echo "building $arch"

  ### docker names the 32-bit x86 architecture "386" in image metadata
  docker_arch=$arch
  if [ "$arch" = "i386" ]; then
    docker_arch=386
  fi

  ### install a minbase system with debootstrap
  debootstrap --variant=minbase --arch=$arch $suite $chroot_dir $apt_mirror

  ### verify the chroot was built for the expected architecture: the ELF class
  ### of /bin/ls (ELFCLASS32/01 for i386, ELFCLASS64/02 for amd64).
  ### Note: uname -m cannot be used here, the host kernel reports its own arch
  ### for the i386 binaries (native ia32 support, qemu-user-static as fallback).
  expected_elf_class=01
  if [ "$arch" = "amd64" ]; then
    expected_elf_class=02
  fi
  elf_class=`od -An -tx1 -j4 -N1 $chroot_dir/bin/ls | tr -d ' '`
  echo "chroot $arch ELF class: $elf_class"
  if [ "$elf_class" != "$expected_elf_class" ]; then
    echo "FAIL: chroot $arch expected ELF class $expected_elf_class, got $elf_class"
    exit 1
  fi

  ### update the list of package sources
  sudo cat <<EOF > $chroot_dir/etc/apt/sources.list
deb $apt_mirror $suite main contrib non-free
deb $apt_mirror $suite-updates main contrib non-free
deb $apt_mirror $suite-backports main contrib non-free

deb $apt_mirror $suite main
EOF

  cp /etc/resolv.conf $chroot_dir/etc/resolv.conf
  sudo mount -o bind /proc $chroot_dir/proc
  chroot $chroot_dir apt-get update
  chroot $chroot_dir apt-get -y upgrade
  chroot $chroot_dir apt-get -y install gnupg

  ### register the phz apt signing key (binary key, no deprecated apt-key)
  mkdir -p $chroot_dir/etc/apt/trusted.gpg.d
  cp /vagrant/pkg.phz.fi.gpg $chroot_dir/etc/apt/trusted.gpg.d/pkg.phz.fi.gpg
  echo "deb http://pkg.phz.fi/$suite ./" > $chroot_dir/etc/apt/sources.list.d/pkg.phz.fi.list
  chroot $chroot_dir apt-get update
  echo "installing common packages for $arch"
  chroot $chroot_dir apt-get -y install \
    phz-common \
    software-properties-common \
    sudo


  ### install sh2ju
  cp /vagrant/scripts/install-sh2ju.sh $chroot_dir/tmp
  cp /vagrant/tests/* $chroot_dir/tmp
  sudo mkdir -p $chroot_dir/results
  chroot $chroot_dir /tmp/install-sh2ju.sh

  ### cleanup
  chroot $chroot_dir apt-get autoclean
  chroot $chroot_dir apt-get clean
  chroot $chroot_dir apt-get autoremove
  rm $chroot_dir/etc/resolv.conf

  ### kill any processes that are running on chroot
  chroot_pids=$(for p in /proc/*/root; do ls -l $p; done | grep $chroot_dir | cut -d'/' -f3)
  test -z "$chroot_pids" || (kill -9 $chroot_pids; sleep 2)

  ### unmount /proc
  sudo umount $chroot_dir/proc

  ### create a tar archive from the chroot directory
  tar cfz $REPO_DIR/debian-$arch.tgz -C $chroot_dir .

  ### import the tar archive into a docker image with the right architecture metadata
  docker build --platform linux/$docker_arch --build-arg arch=$arch \
    -f $SCRIPT_DIR/Dockerfile.import \
    -t $docker_image-$arch \
    $REPO_DIR

  ### verify the docker image carries the right architecture
  image_arch=`docker inspect --format '{{.Architecture}}' $docker_image-$arch`
  echo "image $docker_image-$arch arch: $image_arch"
  if [ "$image_arch" != "$docker_arch" ]; then
    echo "FAIL: image $docker_image-$arch expected arch $docker_arch, got $image_arch"
    exit 1
  fi

  ### push the per-architecture image to Docker Hub
  echo "pushing $docker_image-$arch"
  docker push $docker_image-$arch
done

### create and push the multi-arch manifest lists.
### The manifest client resolves registries over HTTPS by default, so
### --insecure is required for plain-HTTP registries (such as a local
### sandbox registry). Docker Hub publishes use HTTPS and no flag.
manifest_flags=""
case "$docker_image" in
  localhost:*|127.0.0.1:*)
    manifest_flags="--insecure"
    ;;
esac
docker manifest create $manifest_flags $docker_image --amend $docker_image-i386 --amend $docker_image-amd64
docker manifest push $manifest_flags $docker_image
docker manifest create $manifest_flags $LATEST --amend $docker_image-i386 --amend $docker_image-amd64
docker manifest push $manifest_flags $LATEST

### verify the manifest list contains both architectures
docker manifest inspect $manifest_flags $LATEST
