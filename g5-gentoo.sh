#!/bin/bash

# Gentoo installation script for ppc64be 

set -e -o pipefail
set -x
mac-fdisk /dev/sda << EOF
i
y

b
2p
c
3p
4G
swap
c
4p
4p
root
w
y
EOF
sleep 1
umount /dev/sda4 || true
mkfs.xfs -f /dev/sda4
mkdir -p /mnt/gentoo
mount /dev/sda4 /mnt/gentoo
stage3_tarball=$(wget -O - https://distfiles.gentoo.org/releases/ppc/autobuilds/current-stage3-ppc64-openrc/latest-stage3-ppc64-openrc.txt | grep '\.tar\.' | awk '{print $1}')
cd /mnt/gentoo
url=https://distfiles.gentoo.org/releases/ppc/autobuilds/current-stage3-ppc64-openrc/$stage3_tarball
wget -O - $url | unxz | tar xp --xattrs-include='*.*' --numeric-owner
hformat -l bootstrap /dev/sda2
mkdir -p /mnt/gentoo/tmp/bootstrap
mount --types hfs /dev/sda2 /mnt/gentoo/tmp/bootstrap
grub-install --boot-directory=/mnt/gentoo/boot --macppc-directory=/mnt/gentoo/tmp/bootstrap /dev/sda2
umount /mnt/gentoo/tmp/bootstrap/
hmount /dev/sda2
hattrib -t tbxi -c UNIX :System:Library:CoreServices:BootX
hattrib -b :System:Library:CoreServices
humount
cd /mnt/cdrom/boot
cp -a ppc64 /mnt/gentoo/boot/vmlinuz-6.12.41-gentoo
cp -a ppc64.igz /mnt/gentoo/boot/initramfs-6.12.41-gentoo.img
cp -a grub /mnt/gentoo/boot/
cp -a System-ppc64.map /mnt/gentoo/boot/System.map
mkdir -p /mnt/gentoo/lib/modules
cp -a /lib/modules/6.12.41-gentoo-ppc64-ppc /mnt/gentoo/lib/modules
cat > /mnt/gentoo/boot/grub/grub.cfg << EOF
set default=0
set gfxpayload=keep
set timeout=3
insmod all_video

menuentry 'Gentoo Linux (ppc64)' --class gnu-linux --class os {
	linux /boot/vmlinuz-6.12.41-gentoo root=/dev/sda4 ro
	initrd /boot/initramfs-6.12.41-gentoo.img
}
EOF
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run
chroot /mnt/gentoo /bin/bash << 'ENDCHROOT'
set -e -o pipefail
source /etc/profile
passwd << EOF
root
root
EOF
useradd -g users -G wheel,portage,audio,video,usb,cdrom -m gentoo
passwd gentoo << EOF
gentoo
gentoo
EOF
locale-gen
echo gentoo > /etc/hostnamev
cat << EOF > /etc/portage/make.conf 
# These settings were set by the catalyst build script that automatically
# built this stage.
# Please consult /usr/share/portage/config/make.conf.example for a more
# detailed example.
COMMON_FLAGS="-mcpu 970 -O2 -maltivec -mabi=altivec -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j5"
USE="X udev dbus lto lm-sensors ibm ieee1394 opencl opengl -systemd -nvenc -wayland -xwayland -qt5 -qt6 -kde -gnome"
ACCEPT_LICENSES="*"
ACCEPT_KEYWORDS="~ppc64"
INPUT_DEVICES="libinput"
VIDEO_CARDS="nouveau"
GRUB_PLATFORMS="ieee1275"

# WARNING: Changing your CHOST is not something that should be done lightly.
# Please consult https://wiki.gentoo.org/wiki/Changing_the_CHOST_variable before changing.
CHOST="powerpc64-unknown-linux-gnu"

# NOTE: This stage was built with the bindist USE flag enabled

# This sets the language of build output to English.
# Please keep this setting intact when reporting bugs.
LC_MESSAGES=C.utf8
EOF
reboot
