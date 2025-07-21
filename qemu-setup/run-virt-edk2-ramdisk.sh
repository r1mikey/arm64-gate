#!/bin/sh

QEMU_SCRIPT_MACHINE="${QEMU_SCRIPT_MACHINE:-virt,gic-version=2}"
QEMU_SCRIPT_MEMORY="${QEMU_SCRIPT_MEMORY:-6g}"
QEMU_SCRIPT_NCPU="${QEMU_SCRIPT_NCPU:-4}"
QEMU_SCRIPT_CPU="${QEMU_SCRIPT_CPU:-neoverse-n1}"
QEMU_SCRIPT_ACCEL="${QEMU_SCRIPT_ACCEL:-tcg,thread=multi}"

vnic=braich0

if [ ! -f edk2-aarch64-code.fd ]; then
    if [ ! -f /opt/ooce/qemu/share/qemu/edk2-aarch64-code.fd ]; then
        echo "No edk2-aarch64-code.fd found" 1>&2
        exit 1
    fi
    cp /opt/ooce/qemu/share/qemu/edk2-aarch64-code.fd eficode.fd
    truncate -s 64M eficode.fd
fi

if [ ! -f efivars.fd ]; then
    dd if=/dev/zero of=efivars.fd bs=1M count=64
fi

mac=`dladm show-vnic -p -o MACADDRESS $vnic | \
    /bin/awk -F: '{printf("%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6)}' | \
    tr '[:lower:]' '[:upper:]'`

exec qemu-system-aarch64 \
    -s \
    -nographic \
    -machine "${QEMU_SCRIPT_MACHINE}" \
    -accel "${QEMU_SCRIPT_ACCEL}" \
    -m ${QEMU_SCRIPT_MEMORY} \
    -smp cores="${QEMU_SCRIPT_NCPU}" \
    -cpu "${QEMU_SCRIPT_CPU}" \
    -drive if=pflash,format=raw,file=eficode.fd,readonly=on \
    -drive if=pflash,format=raw,file=efivars.fd \
    -netdev vnic,ifname=braich0,id=net0 \
    -device virtio-net-device,netdev=net0,mac=${mac} \
    \
    -device usb-ehci,id=ehci \
      -drive if=none,id=stick,format=raw,file=../usb-image/bootable.usb \
      -device usb-storage,bus=ehci.0,drive=stick,removable=on \
    \
    "$@"

    -drive file=illumos-disk.img,format=raw,id=hd0,if=none \
    -device virtio-blk-device,drive=hd0 \
