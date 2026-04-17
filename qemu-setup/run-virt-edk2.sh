#!/bin/sh

QEMU_SCRIPT_MACHINE="${QEMU_SCRIPT_MACHINE:-virt,gic-version=3,virtualization=on}"
QEMU_SCRIPT_MEMORY="${QEMU_SCRIPT_MEMORY:-2g}"
QEMU_SCRIPT_NCPU="${QEMU_SCRIPT_NCPU:-2}"
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
    -drive file=illumos-disk.img,format=raw,id=hd0,if=none \
    -device virtio-blk-device,drive=hd0 \
    -netdev vnic,ifname=braich0,id=net0 \
    -device virtio-net-device,netdev=net0,mac=${mac} \
    \
    "$@"
    \
    -device pcie-root-port,id=rp01,bus=pcie.0,addr=01.0,port=2,chassis=1 \
      -device pcie-pci-bridge,id=ppb0,bus=rp01,addr=00.0 \
        -device VGA,id=vga0,bus=ppb0,addr=01.0 \
    -device pcie-root-port,id=rp02,bus=pcie.0,addr=02.0,port=4,chassis=2 \
      -netdev user,id=xnic0,hostfwd=tcp::2222-:22 \
      -device igb,id=x550a,bus=rp02,addr=00.0,netdev=xnic0 \
      -netdev user,id=xnic1,hostfwd=tcp::2223-:22 \
      -device igb,id=x550b,bus=rp02,addr=01.0,netdev=xnic1 \
    -device pcie-root-port,id=rp03,bus=pcie.0,addr=03.0,port=6,chassis=3 \
      -device nec-usb-xhci,id=xhci,bus=rp03,addr=00.0 \
    -device pcie-root-port,id=rp04,bus=pcie.0,addr=04.0,port=8,chassis=4 \
      -netdev user,id=xnic2,hostfwd=tcp::2224-:22 \
      -device igb,id=i210a,bus=rp04,addr=00.0,netdev=xnic2 \
    -device pcie-root-port,id=rp05,bus=pcie.0,addr=05.0,port=10,chassis=5 \
    \
