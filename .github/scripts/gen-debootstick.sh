#!/bin/bash

set -e
set -o errexit

TIMESTAMP=$(date +%s)
CHROOT=./image-root-$TIMESTAMP
IMAGE_NAME=regolith-3_3-trixie-$TIMESTAMP.img

if [ -d $CHROOT ]; then
    echo "$CHROOT dir already exists. Aborting."
    exit 1
fi

debootstrap --arch=amd64 --variant=minbase trixie $CHROOT

# Mount required filesystems
mount -t proc /proc $CHROOT/proc
mount --rbind /sys  $CHROOT/sys
mount --make-rslave $CHROOT/sys
mount --rbind /dev  $CHROOT/dev
mount --make-rslave $CHROOT/dev
mount -t devpts devpts $CHROOT/dev/pts

# Enter the chroot
echo "root:boot" | chroot $CHROOT chpasswd
cp gen-debootstick-rootfs.sh $CHROOT
chroot $CHROOT ./gen-debootstick-rootfs.sh
rm $CHROOT/gen-debootstick-rootfs.sh

# Cleanup after exit
umount -l $CHROOT/proc || true
umount -l $CHROOT/sys || true
umount -l $CHROOT/dev/pts || true
umount -l $CHROOT/dev || true

debootstick $CHROOT $IMAGE_NAME

echo "Ready to write $IMAGE_NAME to device"