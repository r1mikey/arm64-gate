#!/bin/sh -x

if [ ! -f michael/boot_archive ]; then
  exit 1
fi

if [ ! -f michael/boot_archive.gz ]; then
  gzip -c michael/boot_archive > michael/boot_archive.gz
fi

cp illumos-gate/proto/root_aarch64/platform/ARM,sbsa/kernel/aarch64/unix.shim michael/unix.shim
cp illumos-gate/proto/root_aarch64/platform/ARM,sbsa/kernel/aarch64/unix michael/unix
cp illumos-gate/proto/root_aarch64/platform/armv8/kernel/drv/aarch64/rootnex michael/rootnex
cp illumos-gate/proto/root_aarch64/kernel/aarch64/genunix michael/genunix
cp illumos-gate/proto/root_aarch64/platform/ARM,sbsa/kernel/misc/aarch64/uefirt michael/uefirt
cp illumos-gate/proto/root_aarch64/platform/ARM,sbsa/kernel/tod/aarch64/toduefi michael/toduefi
cp illumos-gate/proto/root_aarch64/kernel/misc/aarch64/acpica michael/acpica
cp illumos-gate/proto/root_aarch64/platform/armv8/kernel/drv/aarch64/gicv3 michael/gicv3
# any others we're hacking on

pfexec /bin/ksh -p illumos-gate/usr/src/cmd/boot/scripts/root_archive.ksh unpack michael/boot_archive.gz $PWD/michael/boot_archive.dir
pfexec cp michael/unix.shim michael/boot_archive.dir/platform/ARM,sbsa/kernel/aarch64/unix.shim
pfexec cp michael/unix michael/boot_archive.dir/platform/ARM,sbsa/kernel/aarch64/unix
pfexec cp michael/rootnex michael/boot_archive.dir/platform/armv8/kernel/drv/aarch64/rootnex
pfexec cp michael/genunix michael/boot_archive.dir/kernel/aarch64/genunix
pfexec mkdir -p michael/boot_archive.dir/platform/ARM,sbsa/kernel/misc/aarch64
pfexec cp michael/uefirt michael/boot_archive.dir/platform/ARM,sbsa/kernel/misc/aarch64/uefirt
pfexec mkdir -p michael/boot_archive.dir/platform/ARM,sbsa/kernel/tod/aarch64
pfexec cp michael/toduefi michael/boot_archive.dir/platform/ARM,sbsa/kernel/tod/aarch64/toduefi
pfexec mkdir -p michael/boot_archive.dir/kernel/misc/aarch64
pfexec cp michael/acpica michael/boot_archive.dir/kernel/misc/aarch64/acpica
pfexec mkdir -p michael/boot_archive.dir/platform/armv8/kernel/drv/aarch64
pfexec cp michael/gicv3 michael/boot_archive.dir/platform/armv8/kernel/drv/aarch64

(cd michael/boot_archive.dir;
  sudo mkisofs -quiet -graft-points -dlrDJN -relaxed-filenames -o ../boot_archive /boot=./boot /etc=./etc /kernel=./kernel /platform=./platform)
