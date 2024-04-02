#!/bin/bash
set -e

sudo install -do $(id -u) -g $(id -g) rootfs/build
wget -nv -c https://mirrors.edge.kernel.org/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.gz{,.sig}
gpg --verify --auto-key-retrieve --keyserver hkps://keyserver.ubuntu.com archlinux-bootstrap-x86_64.tar.gz.sig
sudo tar -xf archlinux-bootstrap-x86_64.tar.gz --strip-components=1 -C rootfs
sudo cp /etc/resolv.conf rootfs/etc/
sudo sed -i '/kernel.org/s/^#//' rootfs/etc/pacman.d/mirrorlist
sudo sed -i 's/CheckSpace/#&/;/^#\(Color\|VerbosePkgLists\|ParallelDownloads\)/s/^#//' rootfs/etc/pacman.conf

sudo mount -v --bind /dev rootfs/dev
sudo mount -v --bind /dev/pts rootfs/dev/pts
sudo mount -vt proc proc rootfs/proc
sudo mount -vt sysfs sysfs rootfs/sys
sudo mount -vt tmpfs tmpfs rootfs/run
sudo mount -vt tmpfs tmpfs rootfs/tmp
if [ -h rootfs/dev/shm ]; then sudo mkdir -pv rootfs/$(readlink rootfs/dev/shm); else sudo mount -vt tmpfs -o nosuid,nodev devshm rootfs/dev/shm; fi

chroot_run() {
	sudo chroot rootfs \
		/usr/bin/env -i HOME=/root \
		TERM=$TERM PATH=/usr/bin:/usr/sbin \
		/bin/bash --login -c "$*"
}

chroot_run pacman-key --init
chroot_run pacman-key --populate
chroot_run pacman -Syu --noconfirm base-devel
chroot_run useradd builder -mu $UID -G wheel

sudo sed -i '/%wheel .* NOPASSWD/s/^#//' rootfs/etc/sudoers
sudo sh -c "echo PKGDEST=/build/repo >> rootfs/etc/makepkg.conf"
sudo sed -i '/gpg .* --verify/s/gpg/& --auto-key-retrieve/' rootfs/usr/share/makepkg/integrity/verify_signature.sh

URL="https://github.com/$GITHUB_REPOSITORY/releases/latest/download"
if wget -q $URL/mingw.db; then
	sudo sed -i '/^\[core\]$/i\[mingw]\nSigLevel = Optional TrustAll\nServer = %SERVER%\n' rootfs/etc/pacman.conf
	sudo sed -i "s|%SERVER%$|$URL|" rootfs/etc/pacman.conf
	chroot_run pacman -Syu --noconfirm
fi

if [[ $1 == no-bootstrap ]]; then
	sed -i 's@--prefix=/usr@& --disable-bootstrap@' mingw-w64-gcc/PKGBUILD
fi
