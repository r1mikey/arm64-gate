#!/bin/sh

QEMU_SCRIPT_MEMORY="${QEMU_SCRIPT_MEMORY:-4g}"
QEMU_SCRIPT_NCPU="${QEMU_SCRIPT_NCPU:-4}"
QEMU_SCRIPT_CPU="${QEMU_SCRIPT_CPU:-neoverse-n2}"
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
     -machine sbsa-ref \
     -accel "${QEMU_SCRIPT_ACCEL}" \
     -m ${QEMU_SCRIPT_MEMORY} \
     -cpu "${QEMU_SCRIPT_CPU}" \
     -smp cores="${QEMU_SCRIPT_NCPU}" \
     -pflash SBSA_FLASH0.fd \
     -pflash SBSA_FLASH1.fd \
     -serial mon:stdio \
     -nographic \
     -hda illumos-disk.img \
     "$@"
