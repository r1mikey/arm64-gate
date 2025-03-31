#!/bin/ksh93

DISK=$PWD/rpi4-edk2-setup/illumos-disk.img
POOL=armpool			# Must match build_image
MNT=/mnt
ROOTFS=ROOT/braich
ROOT=$MNT/$ROOTFS
DISKSIZE=4g
BE_UUID=`/usr/bin/uuidgen`

set -e

if [[ ! -f Makefile || ! -d illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
	exit 2
fi

if [[ ! -f src/firmware-edk2-rpi4/RPI_EFI.fd ]]; then
	print -u2 "Did you forget to run download-edk2-rpi4?"
	exit 2
fi

if [[ ! -f illumos-gate/proto/root_aarch64/boot/loader64.efi ]]; then
	print -u2 "Did you forget to build loader64.efi?"
	exit 2
fi

if [[ $(zonename) != global ]]; then
	print -u2 "$0 should be run in the global zone"
	exit 2
fi

# Populate the boot directory, which contains the files that should be copied
# to the first (FAT) partition on the SD card.

boot=$PWD/rpi4-edk2-setup/boot
rm -rf $boot
mkdir -p $boot

( ( cd src/firmware-edk2-rpi4 ; tar -cf - .) | ( cd $boot ; tar -xf - ) )
# the 1.41 release has not updated device-tree addresses yet
sed -i \
    -e 's/^device_tree_address=.*/device_tree_address=0x3e0000/g' \
    -e 's/^device_tree_end=.*/device_tree_end=0x400000/g' \
    $boot/config.txt
mkdir $boot/EFI
mkdir $boot/EFI/Boot
cp illumos-gate/proto/root_aarch64/boot/loader64.efi $boot/EFI/Boot/bootaa64.efi

mkfile $DISKSIZE $DISK
BLK_DEVICE=$(sudo lofiadm -la $DISK)
RAW_DEVICE=${BLK_DEVICE/dsk/rdsk}

print "Building a GPT-partitioned image"

# This is the easier option, we can just use the -B option to zpool
# to get it to create an initial FAT partition for us.
sudo zpool create \
    -B -o bootsize=256M \
    -t $POOL -m $MNT $POOL ${BLK_DEVICE%p0}

FAT_RAW=${RAW_DEVICE/p0/s0}
FAT_BLK=${BLK_DEVICE/p0/s0}

print "Populating root"

sudo zfs create -o canmount=noauto -o mountpoint=legacy $POOL/ROOT

pv < out/illumos.zfs | sudo zfs receive -u $POOL/$ROOTFS
sudo zfs set canmount=noauto $POOL/$ROOTFS
sudo zfs set mountpoint=legacy $POOL/$ROOTFS
sudo zfs set org.opensolaris.libbe:uuid=$BE_UUID $POOL/$ROOTFS
sudo zfs set org.opensolaris.libbe:policy=static $POOL/$ROOTFS

sudo zfs create -sV 1G $POOL/swap
sudo zfs create -V 1G $POOL/dump

sudo zpool set bootfs=$POOL/$ROOTFS $POOL
sudo zpool set cachefile="" $POOL
sudo zfs set canmount=noauto $POOL
sudo zfs set mountpoint=/$POOL $POOL
sudo zpool export $POOL

print "Populating boot"

# Format the FAT partition and copy in the boot files.
yes | sudo mkfs -F pcfs -o fat=32,b=bootfs $FAT_RAW
sudo mount -F pcfs $FAT_BLK $MNT
{ cd $boot; find . | sudo cpio -pmud $MNT 2>/dev/null || true; cd -; }
sudo umount $MNT

sudo lofiadm -d $DISK
