#!/bin/sh -xe

pfexec rm -rf michael/boot_archive michael/boot_archive.dir michael/boot_archive.gz michael/genunix michael/rootnex michael/unix michael/unix.shim

ksh tools/build_disk.sh
