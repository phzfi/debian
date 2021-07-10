#!/bin/bash -ex
### Build a docker image for ubuntu i386.

SUITE=bionic
if [ ! -z $1 ]; then
    SUITE=$1
fi

VERSION=$2
USER=$3
PASSWORD=$4

if [ -z "$VERSION" ]; then
  echo "Usage: ./build.sh <version>, e.g. ./build.sh latest user password"
  exit 1
fi
if [ -z "$USER" ]; then
  echo "Usage: ./build.sh <version>, e.g. ./build.sh latest user password"
  exit 1
fi
if [ -z "$PASSWORD" ]; then
  echo "Usage: ./build.sh <version>, e.g. ./build.sh latest user password"
  exit 1
fi

#login to docker hub
docker login -u $USER -p $PASSWORD

### settings
arch=i386
suite=${1:-bionic}
date=`date +%Y%m%d`
chroot_dir="/var/chroot/$suite"
apt_mirror='http://fi.archive.ubuntu.com/ubuntu'
docker_image="phzfi/ubuntu32:$suite-$VERSION"
LATEST="phzfi/ubuntu32:latest"

# Verify tools
TEST=`which debootstrap |wc -l`
if test $TEST -eq 0; then
    echo "FAIL: Required tool debootrap is missing"
    exit 1
fi
TEST=`which schroot |wc -l`
if test $TEST -eq 0; then
    echo "FAIL: Required tool schroot is missing"
    exit 1
fi

### install a minbase system with debootstrap
export DEBIAN_FRONTEND=noninteractive
sudo debootstrap --variant=minbase --arch=$arch $suite $chroot_dir $apt_mirror

### update the list of package sources
sudo cat <<EOF > $chroot_dir/etc/apt/sources.list
deb $apt_mirror $suite main restricted universe multiverse
deb $apt_mirror $suite-updates main restricted universe multiverse
deb $apt_mirror $suite-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $suite-security main restricted universe multiverse

deb $apt_mirror $suite main
EOF

### install ubuntu-minimal
cp /etc/resolv.conf $chroot_dir/etc/resolv.conf
sudo mount -o bind /proc $chroot_dir/proc
chroot $chroot_dir apt-get update
chroot $chroot_dir apt-get -y upgrade
chroot $chroot_dir apt-get -y install ubuntu-minimal gnupg2

cp /vagrant/phz.gpg $chroot_dir/root/phz.gpg
chroot $chroot_dir apt-key add /root/phz.gpg
echo "deb http://pkg.phz.fi/$suite ./" > $chroot_dir/etc/apt/sources.list.d/pkg.phz.fi.list
chroot $chroot_dir apt-get update
chroot $chroot_dir apt-get -y install phz-common



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
tar cfz ubuntu.tgz -C $chroot_dir .

### import this tar archive into a docker image:
cat ubuntu.tgz | docker import - $docker_image --message "Build with https://github.com/phzfi/ubuntu32"

# ### push image to Docker Hub
docker tag $docker_image $docker_image
docker tag $docker_image $LATEST
docker push $docker_image
docker push $LATEST

### cleanup
#rm ubuntu.tgz
#rm -rf $chroot_dir
