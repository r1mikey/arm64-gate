#!/bin/bash -xe

BUILD_AREA=/build/arm64-gate/illumos-gate/proto/root_aarch64

copyin() {
	if [ -e "${BUILD_AREA}/${1}" ]; then
		pfexec mkdir -p /mnt/$(dirname "${1}")
		pfexec cp "${BUILD_AREA}/${1}" "/mnt/${1}"
	fi
}

pfexec lofiadm -la illumos-disk.img
pfexec zpool import -a -f
pfexec zfs set mountpoint=/mnt armpool/ROOT/braich
pfexec zfs mount armpool/ROOT/braich

copyin kernel/aarch64/genunix
copyin platform/armv8/kernel/misc/aarch64/acpidev
copyin platform/armv8/kernel/drv/aarch64/acpinex
copyin platform/armv8/kernel/drv/aarch64/arm_gtmr
copyin kernel/misc/aarch64/bootdev
copyin platform/armv8/kernel/dacf/aarch64/consconfig_dacf
copyin platform/armv8/kernel/drv/aarch64/ecam
copyin platform/armv8/kernel/drv/aarch64/efifb
copyin platform/armv8/kernel/misc/aarch64/gfx_private
copyin platform/armv8/kernel/drv/aarch64/gicthree
copyin platform/armv8/kernel/drv/aarch64/gictwo
copyin platform/armv8/kernel/drv/aarch64/gicv2m
copyin platform/armv8/kernel/drv/aarch64/gicv3_its
copyin platform/armv8/kernel/drv/aarch64/ns16550a
copyin platform/armv8/kernel/misc/aarch64/pci_prd
copyin kernel/misc/aarch64/pcicfg
copyin platform/armv8/kernel/misc/aarch64/pcie
copyin kernel/drv/aarch64/efidev
copyin kernel/drv/aarch64/pcieb
copyin platform/armv8/kernel/misc/aarch64/pcierc
copyin kernel/misc/aarch64/pcierc

copyin platform/armv8/kernel/tod/aarch64/efitod
copyin platform/armv8/kernel/tod/aarch64/pl03one
copyin platform/armv8/kernel/misc/aarch64/platmod
copyin platform/armv8/kernel/drv/aarch64/rootnex
copyin platform/RaspberryPi,4/kernel/drv/aarch64/bcm2711_emmctwo
copyin platform/RaspberryPi,4/kernel/drv/aarch64/bcm2711_genet
copyin platform/RaspberryPi,4/kernel/drv/aarch64/bcm2711_pcie
copyin platform/RaspberryPi,4/kernel/drv/aarch64/bcm2711_sensors
copyin platform/RaspberryPi,4/kernel/misc/aarch64/platmod
copyin platform/ARMH,sbbr/kernel/aarch64/unix
copyin platform/ARMH,sbbr/kernel/misc/aarch64/platmod
copyin platform/armv8/kernel/drv/aarch64/simple-bus
copyin platform/armv8/kernel/aarch64/unix
copyin platform/QEMU,virt/kernel/misc/aarch64/platmod

pfexec touch /mnt/reconfigure

pfexec /mnt/boot/solaris/bin/create_ramdisk -R /mnt -p aarch64 -f cpio
# Expand the filelist that was used to create our boot archive into a format
# suitable for use as the archive cache and as input to stat cache production.
(
    cd /mnt
    /mnt/boot/solaris/bin/extract_boot_filelist \
        -R /mnt -p aarch64 boot/solaris/filelist.ramdisk \
        etc/boot/solaris/filelist.ramdisk \
        | while read file; do
            [ -e "$file" ] && find "$file" -type f
        done | awk '{printf("/%s=%s\n", $1, $1)}' | \
    pfexec tee platform/armv8/aarch64/archive_cache > /dev/null 2>&1
    pfexec chmod 644 platform/armv8/aarch64/archive_cache
)
# Now create the stat cache.
pfexec ../build/barn -R /mnt -w /mnt/platform/armv8/aarch64/archive_cache
pfexec touch /mnt/boot/solaris/timestamp.cache

pfexec zfs unmount -f armpool/ROOT/braich
pfexec zfs set mountpoint=legacy armpool/ROOT/braich
pfexec zpool export armpool
pfexec lofiadm -d illumos-disk.img
