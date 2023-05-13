#!/bin/sh -xe

pfexec rm -rf michael/boot_archive michael/boot_archive.dir michael/boot_archive.gz michael/genunix michael/rootnex michael/unix michael/unix.shim

tools/build_image.sh
tools/build_qemu.sh
