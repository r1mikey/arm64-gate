#!/bin/sh

# QEMU_SCRIPT_MACHINE="${QEMU_SCRIPT_MACHINE:-virt,virtualization=on,gic-version=3,dumpdtb=mikey.dtb}"
# QEMU_SCRIPT_MACHINE="${QEMU_SCRIPT_MACHINE:-virt,virtualization=off,gic-version=2,virtio-mmio-transports=0}"
QEMU_SCRIPT_MACHINE="${QEMU_SCRIPT_MACHINE:-virt,gic-version=3,virtualization=on,virtio-mmio-transports=0}"
# QEMU_SCRIPT_MACHINE="${QEMU_SCRIPT_MACHINE:-virt,gic-version=3,msi=gicv2m,virtio-mmio-transports=0}"
QEMU_SCRIPT_MEMORY="${QEMU_SCRIPT_MEMORY:-4g}"
QEMU_SCRIPT_NCPU="${QEMU_SCRIPT_NCPU:-4}"
QEMU_SCRIPT_CPU="${QEMU_SCRIPT_CPU:-neoverse-n1}"
QEMU_SCRIPT_ACCEL="${QEMU_SCRIPT_ACCEL:-tcg,thread=multi}"

if [ ! -f vm.uuid ]; then
	uuidgen > vm.uuid
fi

QEMU_UUID=$(cat vm.uuid)

vnic=braich0

mac=`dladm show-vnic -p -o MACADDRESS $vnic | \
    /bin/awk -F: '{printf("%02s:%02s:%02s:%02s:%02s:%02s",$1,$2,$3,$4,$5,$6)}' | \
    tr '[:lower:]' '[:upper:]'`

#    -smp cores="${QEMU_SCRIPT_NCPU}"
#    -m ${QEMU_SCRIPT_MEMORY}
#
#    -smp 4,sockets=1,clusters=2,cores=2,threads=1

# -smp 16,sockets=2,clusters=2,cores=2,threads=2
# -smp 4,sockets=2,cores=2
# -smp 4,sockets=1,cores=2,threads=2
# -smp 4

#
#
#    -m 4G \
#    -smp 4,sockets=2,cores=2,threads=1 \
#    -object memory-backend-ram,id=mem0,size=2G \
#    -object memory-backend-ram,id=mem1,size=2G \
#    -numa node,nodeid=0,cpus=0-1,memdev=mem0 \
#    -numa node,nodeid=1,cpus=2-3,memdev=mem1 \
#    -numa dist,src=0,dst=0,val=10 \
#    -numa dist,src=0,dst=1,val=20 \
#    -numa dist,src=1,dst=0,val=20 \
#    -numa dist,src=1,dst=1,val=10 \
#
#

set -x
exec qemu-system-aarch64 \
    -s \
    -nographic \
    -uuid "${QEMU_UUID}" \
    -machine "${QEMU_SCRIPT_MACHINE}" \
    -accel "${QEMU_SCRIPT_ACCEL}" \
    \
    -smp 4,sockets=2,cores=2,threads=1 \
    -m 4g \
    -object memory-backend-ram,id=mem0,size=2G \
    -object memory-backend-ram,id=mem1,size=2G \
    -numa node,nodeid=0,cpus=0-1,memdev=mem0 \
    -numa node,nodeid=1,cpus=2-3,memdev=mem1 \
    -numa dist,src=0,dst=0,val=10 \
    -numa dist,src=0,dst=1,val=20 \
    -numa dist,src=1,dst=0,val=20 \
    -numa dist,src=1,dst=1,val=10 \
    \
    -cpu "${QEMU_SCRIPT_CPU}" \
    -bios u-boot.bin \
    -drive file=$PWD/illumos-disk.img,format=raw,id=hd0,if=none \
    -device virtio-blk-pci,drive=hd0,bootindex=1 \
    -netdev vnic,ifname=braich0,id=net0 \
    -device virtio-net-pci,netdev=net0,mac=${mac} \
    \
    \
    "$@"

USE THIS
    -device pci-serial \
    -device qemu-xhci,id=xhci \
    -device usb-hub,bus=xhci.0,port=1 \
    \
    -device pcie-root-port,id=rp0,slot=1,chassis=1,bus=pcie.0 \
      -device x3130-upstream,id=sw0,bus=rp0 \
        -device xio3130-downstream,id=dp0,bus=sw0,chassis=10 \
          -netdev user,id=n0 \
          -device igb,bus=dp0,mac=30:23:03:e1:ff:28,netdev=n0 \
        -device xio3130-downstream,id=dp1,bus=sw0,chassis=11 \
          -device x3130-upstream,id=sw1,bus=dp1 \
            -device xio3130-downstream,id=dp2,bus=sw1,chassis=20 \
              -netdev user,id=n1 \
              -device igb,bus=dp2,mac=30:23:03:e1:ff:29,netdev=n1 \
            -device xio3130-downstream,id=dp3,bus=sw1,chassis=21 \
              -device x3130-upstream,id=sw2,bus=dp3 \
                -device xio3130-downstream,id=dp4,bus=sw2,chassis=30 \
                  -netdev user,id=n2 \
                  -device igb,bus=dp4,mac=30:23:03:e1:ff:2a,netdev=n2 \
            -device xio3130-downstream,id=dp5,bus=sw1,chassis=22 \
              -netdev user,id=n3 \
              -device igb,bus=dp5,mac=30:23:03:e1:ff:2b,netdev=n3 \
            -device xio3130-downstream,id=dp6,bus=sw1,chassis=23 \
              -device pci-bridge,id=br0,bus=dp6,chassis_nr=40 \
                -netdev user,id=n4 \
                -device e1000,bus=br0,addr=1,mac=30:23:03:e1:ff:2c,netdev=n4 \
                -device pci-bridge,id=br1,bus=br0,chassis_nr=41,addr=2 \
                  -netdev user,id=n5 \
                  -device e1000,bus=br1,addr=1,mac=30:23:03:e1:ff:2d,netdev=n5 \
                  -netdev user,id=n6 \
                  -device e1000,bus=br1,addr=2,mac=30:23:03:e1:ff:2e,netdev=n6 \
    -device pcie-root-port,id=rp1,slot=2,chassis=2,bus=pcie.0 \
      -device x3130-upstream,id=sw3,bus=rp1 \
        -device xio3130-downstream,id=dp7,bus=sw3,chassis=50 \
          -netdev user,id=n7 \
          -device igb,bus=dp7,mac=30:23:03:e1:ff:2f,netdev=n7 \
        -device xio3130-downstream,id=dp8,bus=sw3,chassis=51 \
          -device pci-bridge,id=br2,bus=dp8,chassis_nr=60 \
            -netdev user,id=n8 \
            -device e1000,bus=br2,addr=1,mac=30:23:03:e1:ff:30,netdev=n8 \
            -device pci-bridge,id=br3,bus=br2,chassis_nr=61,addr=2 \
              -netdev user,id=n9 \
              -device e1000,bus=br3,addr=1,mac=30:23:03:e1:ff:31,netdev=n9 \

WINNER
    -device pcie-root-port,id=rp0,slot=0,chassis=0,bus=pcie.0 \
      -device x3130-upstream,id=sw0,bus=rp0 \
        -device xio3130-downstream,id=dp0,bus=sw0,chassis=2 \
          -device virtio-net-pci-non-transitional,netdev=net0,mac=${mac},bus=dp0 \
    -device pcie-root-port,id=rp1,slot=1,chassis=1,bus=pcie.0 \
      -device pci-bridge,id=br0,bus=rp1,chassis_nr=3 \
        -device e1000,bus=br0,addr=1 \
    -device pcie-root-port,id=rp2,slot=2,chassis=2,bus=pcie.0 \
      -device x3130-upstream,id=sw1,bus=rp2 \
        -device xio3130-downstream,id=dp1,bus=sw1,chassis=3 \
          -device x3130-upstream,id=sw2,bus=dp1 \
            -device xio3130-downstream,id=dp2,bus=sw2,chassis=4 \
              -device pci-bridge,id=br1,bus=dp2,chassis_nr=4 \
                -device pci-bridge,id=br2,bus=br1,chassis_nr=5,addr=1 \
                  -device e1000,bus=br2,addr=1 \

    -device pcie-root-port,id=rp0,slot=0,chassis=0,bus=pcie.0 \
      -device x3130-upstream,id=sw0,bus=rp0 \
        -device xio3130-downstream,id=dp0,bus=sw0,chassis=2 \
          -device virtio-net-pci,netdev=net0,mac=${mac},bus=dp0 \
    -device pcie-root-port,id=rp1,slot=1,chassis=1,bus=pcie.0 \
      -device pci-bridge,id=br0,bus=rp1,chassis_nr=3 \
        -device virtio-blk-pci,drive=hd0,bootindex=1,bus=br0,addr=1 \

    -device pcie-root-port,id=rp0,slot=0,chassis=0,bus=pcie.0 \
      -device x3130-upstream,id=sw0,bus=rp0 \
        -device xio3130-downstream,id=dp0,bus=sw0,chassis=2 \
          -device virtio-net-pci,netdev=net0,mac=${mac},bus=dp0 \
    -device pcie-root-port,id=rp1,slot=1,chassis=1,bus=pcie.0 \
      -device pci-bridge,id=br0,bus=rp1,chassis_nr=3 \
        -device virtio-blk-pci,drive=hd0,bootindex=1,bus=br0,addr=1 \

    -device pcie-root-port,id=rp0,slot=0,chassis=0,bus=pcie.0 \
      -device pci-bridge,id=br0,bus=rp0,chassis_nr=1 \
        -device virtio-blk-pci,drive=hd0,bootindex=1,bus=br0,addr=1 \
    -device pcie-root-port,id=rp1,slot=1,chassis=1,bus=pcie.0 \
      -device virtio-net-pci,netdev=net0,mac=${mac},bus=rp1 \

    -device pcie-root-port,id=rp0,slot=0,chassis=0,bus=pcie.0 \
      -device virtio-blk-pci-transitional,drive=hd0,bootindex=1,bus=rp0 \
    -device pcie-root-port,id=rp1,slot=1,chassis=1,bus=pcie.0 \
      -device virtio-net-pci-transitional,netdev=net0,mac=${mac},bus=rp1 \

    -device pcie-root-port,id=rp0,slot=0,chassis=0,bus=pcie.0 \
      -device virtio-blk-pci,drive=hd0,bootindex=1,bus=rp0 \
    -device pcie-root-port,id=rp1,slot=1,chassis=1,bus=pcie.0 \
      -device virtio-net-pci,netdev=net0,mac=${mac},bus=rp1 \

    -device virtio-blk-pci,drive=hd0,bootindex=1 \
    -device virtio-net-device,netdev=net0,mac=${mac} \

#    -device qemu-xhci,id=xhci \
#    -device usb-hub,bus=xhci.0,port=1 \
#    -device virtio-blk-device,drive=hd0
#    -device virtio-blk-pci,drive=hd0

    -trace 'gicv3*' \
    -D /tmp/qemu-its-trace.log \
      -device piix4-usb-uhci,id=xhci,bus=rp03,addr=00.0 \
        -device usb-kbd,bus=xhci.0 \

exec qemu-system-aarch64 \
     -nographic \
     -machine "${QEMU_SCRIPT_MACHINE}" \
     -accel "${QEMU_SCRIPT_ACCEL}" \
     -m ${QEMU_SCRIPT_MEMORY} \
     -smp cores="${QEMU_SCRIPT_NCPU}" \
     -cpu "${QEMU_SCRIPT_CPU}" \
     -bios u-boot.bin \
     -netdev vnic,ifname=braich0,id=net0 \
     -device virtio-net-pci,netdev=net0,mac=${mac} \
     -device virtio-blk-pci,drive=hd0 \
     -drive file=$PWD/illumos-disk.img,format=raw,id=hd0,if=none \
     "$@"
