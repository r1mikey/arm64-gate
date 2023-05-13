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
     -nographic \
     -machine virt,gic-version=3 \
     -accel tcg,thread=multi \
     -m 3g \
     -smp cores=6 \
     -cpu cortex-a53 \
     -netdev vnic,ifname=braich0,id=net0 \
     -device virtio-net-device,netdev=net0,mac=${mac} \
     -drive if=pflash,format=raw,file=/opt/ooce/qemu/share/qemu/edk2-aarch64-code.fd,readonly=on \
     -drive if=pflash,format=raw,file=../michael/efivars.fd \
     -device virtio-blk-device,drive=hd0 \
     -drive file=$PWD/illumos-disk.img,format=raw,id=hd0,if=none \
     "$@"
# -append "-D /virtio_mmio@a003c00"
