#!/bin/sh -x

QEMU_SCRIPT_MEMORY="${QEMU_SCRIPT_MEMORY:-4g}"
QEMU_SCRIPT_NCPU="${QEMU_SCRIPT_NCPU:-4}"
QEMU_SCRIPT_CPU="${QEMU_SCRIPT_CPU:-neoverse-n1}"
QEMU_SCRIPT_ACCEL="${QEMU_SCRIPT_ACCEL:-tcg,thread=multi}"

vnic=braich0

if [ ! -f SBSA_FLASH0.fd ]; then
    if [ ! -f ../src/edk2-qemu-sbsa-bins/SBSA_FLASH0.fd ]; then
        echo "No SBSA_FLASH0.fd found" 1>&2
        exit 1
    fi
    cp ../src/edk2-qemu-sbsa-bins/SBSA_FLASH0.fd SBSA_FLASH0.fd
    truncate -s 256M SBSA_FLASH0.fd
fi

if [ ! -f SBSA_FLASH1.fd ]; then
    if [ ! -f ../src/edk2-qemu-sbsa-bins/SBSA_FLASH1.fd ]; then
        echo "No SBSA_FLASH1.fd found" 1>&2
        exit 1
    fi
    cp ../src/edk2-qemu-sbsa-bins/SBSA_FLASH1.fd SBSA_FLASH1.fd
    truncate -s 256M SBSA_FLASH1.fd
fi

mac=`dladm show-vnic -p -o MACADDRESS $vnic | \
    /bin/awk -F: '{printf("%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6)}' | \
    tr '[:lower:]' '[:upper:]'`

exec qemu-system-aarch64 \
    -s \
    -machine sbsa-ref \
    -accel "${QEMU_SCRIPT_ACCEL}" \
    -m ${QEMU_SCRIPT_MEMORY} \
    -cpu "${QEMU_SCRIPT_CPU}" \
    -smp cores="${QEMU_SCRIPT_NCPU}" \
    -pflash SBSA_FLASH0.fd \
    -pflash SBSA_FLASH1.fd \
    -serial mon:stdio \
    -nographic \
    \
    -device ahci,id=ahci0,bus=pcie.0,addr=03.0 \
      -drive file=illumos-disk.img,if=none,id=drive0 \
      -device ide-hd,drive=drive0,bus=ahci0.0 \
    \
    \
    "$@"

    \
    -device pcie-root-port,id=rp01,bus=pcie.0,addr=01.0,port=2,chassis=1 \
      -device pcie-pci-bridge,id=ppb0,bus=rp01,addr=00.0 \
        -device ati-vga,id=vga0,bus=ppb0,addr=01.0 \
    -device pcie-root-port,id=rp02,bus=pcie.0,addr=02.0,port=4,chassis=2 \
      -netdev user,id=xnic0,hostfwd=tcp::2222-:22 \
      -device igb,id=x550a,bus=rp02,addr=00.0,netdev=xnic0 \
      -netdev user,id=xnic1,hostfwd=tcp::2223-:22 \
      -device igb,id=x550b,bus=rp02,addr=01.0,netdev=xnic1 \
    -device pcie-root-port,id=rp03,bus=pcie.0,addr=03.0,port=6,chassis=3 \
      -netdev user,id=xnic3,hostfwd=tcp::2225-:22 \
      -device igb,id=x550c,bus=rp03,addr=00.0,netdev=xnic3 \
    -device pcie-root-port,id=rp04,bus=pcie.0,addr=04.0,port=8,chassis=4 \
      -netdev user,id=xnic2,hostfwd=tcp::2224-:22 \
      -device igb,id=i210a,bus=rp04,addr=00.0,netdev=xnic2 \
    -device pcie-root-port,id=rp05,bus=pcie.0,addr=05.0,port=10,chassis=5 \
    \

#     -hda illumos-disk.img
