#!/bin/sh -xe

if [ ! -d michael ]; then
    echo "Must run from the top of the arm64-gate" 1>&2
    exit 1
fi

cd qemu-setup

vnic=braich0

mac=`dladm show-vnic -p -o MACADDRESS $vnic | \
    /bin/awk -F: '{printf("%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6)}' | \
    tr '[:lower:]' '[:upper:]'`

# -machine virt-4.1,gic-version=3
# -machine virt,gic-version=3
# -machine virt,secure -- and -bios /path/to-atf-with-uefi
#     -s -S
exec qemu-system-aarch64 \
     -nographic \
     -machine virt,gic-version=3 \
     -accel tcg,thread=multi \
     -m 1g \
     -smp cores=4 \
     -cpu neoverse-n1 \
     -kernel inetboot.bin \
     -append "-D /virtio_mmio@a003c00 -Bkbm_debug=,prom_debug= -v" \
     -netdev vnic,ifname=braich0,id=net0 \
     -device virtio-net-device,netdev=net0,mac=${mac} \
     -device virtio-blk-device,drive=hd0 \
     -drive file=$PWD/illumos-disk.img,format=raw,id=hd0,if=none \
     "$@"
#     -append "-D /virtio_mmio@a003c00 -Bkbm_debug=,prom_debug= -v"
