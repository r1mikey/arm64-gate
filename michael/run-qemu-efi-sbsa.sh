#!/bin/sh -xe

if [ ! -d michael ]; then
    echo "Must run from the top of the arm64-gate" 1>&2
    exit 1
fi

cd qemu-efi-setup

vnic=braich0

mac=`dladm show-vnic -p -o MACADDRESS $vnic | \
    /bin/awk -F: '{printf("%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6)}' | \
    tr '[:lower:]' '[:upper:]'`

if [ ! -f ../michael/efivars.fd ]; then
    dd if=/dev/zero of=../michael/efivars.fd bs=1M count=64
fi


# -machine virt-4.1,gic-version=3
# -machine virt,gic-version=3
# -machine virt,secure -- and -bios /path/to-atf-with-uefi
exec qemu-system-aarch64 \
     -s \
     -nographic \
     -machine sbsa-ref \
     -accel tcg,thread=multi \
     -m 2g \
     -cpu cortex-a72 \
     -serial mon:stdio \
     -device qemu-xhci \
     -device usb-kbd \
     -device usb-tablet \
     -netdev vnic,ifname=braich0,id=net0 \
     -device e1000,netdev=net0,mac=${mac} \
     -drive if=pflash,format=raw,file=/build/SBSA_FLASH0.fd,readonly=on \
     -drive if=pflash,format=raw,file=/build/SBSA_FLASH1.fd \
     -hda $PWD/illumos-disk.img \
     "$@"
# -append "-D /virtio_mmio@a003c00"

#qemu-system-aarch64 \
#     -nographic \
#     -machine sbsa-ref \
#     -accel tcg,thread=multi \
#     -m 2g \
#     -serial mon:stdio \
#     -pflash /build/SBSA_FLASH0.fd \
#     -pflash /build/SBSA_FLASH1.fd \
#     -hda $PWD/illumos-disk.img
