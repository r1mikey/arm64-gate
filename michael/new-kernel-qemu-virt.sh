#!/bin/bash -xe

#
# For everything, do this instead:
# rm -f stamps/illumos-stamp && make illumos && make image && make qemu-disk
#
# If you also want a Pi image, add 'make rpi4-disk'
#

cd illumos-gate
# usr/src/tools/scripts/bldenv -T aarch64 ../env/aarch64 'cd usr/src/uts && make -j 10 install'
usr/src/tools/scripts/bldenv -T aarch64 ../env/aarch64 'cd usr/src/pkg && make -j 10 install'
cd ..
rm -f out/illumos.zfs
make qemu-efi-disk
# make qemu-disk
# make rpi4-disk

# now do ./run-qemu.sh
