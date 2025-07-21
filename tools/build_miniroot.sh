#!/bin/ksh93

set -e

if [[ ! -f Makefile || ! -d illumos-gate ]]; then
	print -u2 "$0 should be run from the root of arm64-gate"
	exit 2
fi

if [[ $(zonename) != global ]]; then
	print -u2 "$0 should be run in the global zone"
	exit 2
fi

DATASET="$(zfs list -Ho name / | cut -d/ -f1)/braich_image"
ROOT=/braich_image
WORKDIR=$PWD
POOL=armpool # We need to know this to configure swap and dump
USB_FILE=$WORKDIR/usb-image-file

cleanup () {
    set -x

    if [ -e $WORKDIR/mnt2 ]; then
        sudo umount $WORKDIR/mnt2
    fi

    if [ -e $USB_FILE ]; then
        sudo lofiadm -d $USB_FILE
    fi

    if [ -e $WORKDIR/miniroot ]; then
        if [ -e $WORKDIR/mnt ]; then
            sudo umount $WORKDIR/mnt || true
            rm -rf $WORKDIR/mnt
        fi
        sudo lofiadm -d $WORKDIR/miniroot || true
        rm -f $WORKDIR/miniroot
    fi
    sudo zfs destroy -r $DATASET
    sudo rm -f $WORKDIR/miniroot.ufs $WORKDIR/miniroot.gz
    sudo rm -f $WORKDIR/usb-image-file
}

zfs list $DATASET >/dev/null 2>&1 && sudo zfs destroy -r $DATASET
sudo zfs create -o compression=off -o mountpoint=$ROOT $DATASET
# trap 'sudo zfs destroy -r $DATASET' EXIT
trap 'cleanup' EXIT

# Setting this flag lets `pkg` know that this is an automatic installation and
# that the installed packages should not be marked as 'manually installed'
# in the pkg database.
export PKG_AUTOINSTALL=1

ILLUMOS_REPO=$PWD/illumos-gate/packages/aarch64/nightly/repo.redist

sudo pkg image-create --full						\
     --variant variant.arch=aarch64					\
     --variant smrt.aliases=true					\
     --facet doc.man=false						\
     --facet devel=false						\
     --set-property flush-content-cache-on-success=True			\
     --publisher $ILLUMOS_REPO						\
     $ROOT

for publisher in omnios extra.omnios; do
	sudo pkg -R $ROOT set-publisher					\
	     -g file:///$PWD/archives/omnios				\
	     -g https://pkg.omnios.org/bloody/braich			\
	     -m https://us-west.mirror.omnios.org/bloody/braich		\
	     $publisher
done

# We install entire, and also the optional packages listed in entire. These are
# ones that we'd like in the initial image but can be removed by the user if
# desired.
# network/telnet is broken out here because unfortunately the unqualified name
# is ambiguous (it also matches service/network/telnet). We can't just use
# qualified names in general because the pkg://omnios/ packages conflict with
# the newer versions in pkg://on-nightly/.
pkglist=(
	entire
	"pkg://on-nightly/*"
	developer/build-essential
	$(pkg -R $ROOT contents -rH -a type=optional -o fmri entire | \
	    cut -d/ -f4- | egrep -v '(telnet|rsyslog)')
	pkg://on-nightly/network/telnet
)
sudo pkg -R $ROOT install \
     --reject ssh-common \
     --reject system/rsyslog \
     ${pkglist[*]}

sudo pkg -R $ROOT set-publisher				\
    --non-sticky					\
    -G file:///$ILLUMOS_REPO				\
    on-nightly

for publisher in omnios extra.omnios; do
	sudo pkg -R $ROOT set-publisher			\
	    -G file:///$PWD/archives/omnios		\
	    $publisher
done

# fixups
echo " --- updating /etv/vfstab"
(
awk < $ROOT/etc/vfstab > $WORKDIR/vfstab '
    $3 != "/" { print }
    END { print "/devices/ramdisk:a - / ufs - no nologging" }
' && sudo cp $WORKDIR/vfstab $ROOT/etc/vfstab
) || (echo "failed on vfstab / update"; exit 1)
rm $WORKDIR/vfstab

sudo sed -i '/^last_uuid/d' $ROOT/var/pkg/pkg5.image

sudo sed -i '/PermitRootLogin/s/no/yes/' $ROOT/etc/ssh/sshd_config

# Set up a skeleton /dev
sudo tar -xf tools/dev.tar -C $ROOT
sudo touch $ROOT/reconfigure

# Without mdb(8) or kmdb(8) kmem debugging is much less useful, and much too
# slow in the emulator.  This is KMF_DEADBEEF|KMF_REDZONE
#echo "set kmem_flags = 0x6" | sudo tee -a $ROOT/etc/system > /dev/null

# Don't require passwords
sudo sed -i 's/PASSREQ=YES/PASSREQ=NO/' $ROOT/etc/default/login

# Have a host name etc, in case dhcp
echo "braich" | sudo tee -a $ROOT/etc/nodename > /dev/null
sudo sed -i 's/localhost/braich.dev braich localhost/' $ROOT/etc/inet/hosts

# Put the SMF profiles in place
sudo ln -s ns_files.xml $ROOT/etc/svc/profile/name_service.xml
sudo ln -s generic_limited_net.xml $ROOT/etc/svc/profile/generic.xml
sudo ln -s inetd_generic.xml $ROOT/etc/svc/profile/inetd_services.xml
sudo ln -s platform_none.xml $ROOT/etc/svc/profile/platform.xml

# Set the default timezone to UTC
sudo sed -i '/^TZ/c\
TZ=UTC
' $ROOT/etc/default/init

# Import all the services ahead of time.  This is a shame, because allowing
# EMI to happen has found many bugs, but it also takes _forever_
SVCCFG=illumos-gate/usr/src/tools/proto/root_i386-nd/opt/onbld/bin/i386/svccfg
SVCCFG_CONFIGD_PATH=illumos-gate/usr/src/tools/proto/root_i386-nd/opt/onbld/bin/i386/svc.configd
SVCCFG_REPOSITORY=/tmp/arm-gate.$$

cp $ROOT/lib/svc/seed/global.db $SVCCFG_REPOSITORY
chmod u+w $SVCCFG_REPOSITORY
env PKG_INSTALL_ROOT=$ROOT \
    SVCCFG_DTD=$ROOT/usr/share/lib/xml/dtd/service_bundle.dtd.1 \
    SVCCFG_REPOSITORY=$SVCCFG_REPOSITORY \
    SVCCFG_CHECKHASH=1 $SVCCFG import \
		       -p /dev/stdout $ROOT/lib/svc/manifest
sudo cp -a $SVCCFG_REPOSITORY $ROOT/etc/svc/repository.db
sudo chown root:sys $ROOT/etc/svc/repository.db
sudo chmod 0600 $ROOT/etc/svc/repository.db
rm -f $SVCCFG_REPOSITORY

# cleanups
sudo rm -rf \
    $ROOT/var/pkg \
    $ROOT/usr/share/man \
    $ROOT/usr/lib/iconv \
    $ROOT/usr/lib/python2.7 \
    $ROOT/usr/lib/python3.13

sudo rm -rf \
    $ROOT/opt/gcc-14

sudo rm -rf \
    $ROOT/opt/crypto-tests \
    $ROOT/opt/elf-tests \
    $ROOT/opt/ksh93-tests \
    $ROOT/opt/libc-tests \
    $ROOT/opt/libmlrpc-tests \
    $ROOT/opt/libproc-tests \
    $ROOT/opt/libsec-tests \
    $ROOT/opt/net-tests \
    $ROOT/opt/nvme-tests \
    $ROOT/opt/os-tests \
    $ROOT/opt/smbclient-tests \
    $ROOT/opt/smbsrv-tests \
    $ROOT/opt/SUNWdtrt \
    $ROOT/opt/test-runner \
    $ROOT/opt/tz-tests \
    $ROOT/opt/util-tests \
    $ROOT/opt/zfs-tests

NOSTRIP=y
if [ -z "$NOSTRIP" ]; then
    while read bin; do
        echo $bin | egrep -s '^kernel/' && continue
        echo $bin | egrep -s '^platform/' && continue
        sudo file $ROOT/$bin | egrep -s 'ELF.*aarch64.*stripped' || continue
        MODE=`sudo stat -c %a "$ROOT/$bin"`
        sudo chmod u+w "$ROOT/$bin"
        sudo $WORKDIR/build/cross/bin/aarch64-unknown-solaris2.11-strip $ROOT/$bin
        sudo mcs -d -n .SUNW_ctf $ROOT/$bin
    done < <(cd $ROOT && sudo find ./ -type f | cut -c3-)
fi

# add 100MiB
typeset size=`sudo du -ks ${ROOT} | awk '{print $1+102400}'`
size=1572864
rm -f $WORKDIR/miniroot
mkfile ${size}k $WORKDIR/miniroot || (echo "failed on mkfile"; exit 1)
LOFIDEV=`sudo lofiadm -a $WORKDIR/miniroot`
typeset rlofidev=${LOFIDEV/lofi/rlofi}
yes | sudo newfs -m 0 $rlofidev
mkdir -p $WORKDIR/mnt
sudo mount -o nologging $LOFIDEV $WORKDIR/mnt || (echo "mount" ; exit 1)

cd $ROOT
sudo find . | sudo cpio -pdum $WORKDIR/mnt || (echo "populate root" ; exit 1)
cd -

sudo umount $WORKDIR/mnt || (echo "umount" ; exit 1)
rm -rf $WORKDIR/mnt
sudo lofiadm -d $WORKDIR/miniroot || (echo "lofiadm delete" ; exit 1)

mv $WORKDIR/miniroot $WORKDIR/miniroot.ufs
gzip -9c -f $WORKDIR/miniroot.ufs > $WORKDIR/miniroot.gz
# cp $WORKDIR/miniroot.ufs $WORKDIR/miniroot.gz
chmod 644 $WORKDIR/miniroot.gz
gzip -l $WORKDIR/miniroot.gz

set -x

typeset MINIROOT_SIZE=`stat -c %s $WORKDIR/miniroot.gz`
(( USB_SIZE = int((MINIROOT_SIZE * 1.1) / 1024.) * 1024 + 512 ))
((USB_SIZE += 41943040))
UEFI_SIZE=$USB_SIZE
((USB_SIZE += 134217728))

rm -f $USB_FILE
mkfile -n $USB_SIZE $USB_FILE
LOFI_USB=`sudo lofiadm -la $USB_FILE`
RLOFI_USB=${LOFI_USB/dsk/rdsk}

sudo zpool create -B -o bootsize=$UEFI_SIZE usbtmp-$$ ${LOFI_USB/p0/}
sudo zpool destroy usbtmp-$$

FAT_RAW=${RLOFI_USB/p0/s0}
FAT_BLK=${LOFI_USB/p0/s0}

yes | sudo mkfs -F pcfs -o fat=32,b=bootfs $FAT_RAW
mkdir -p $WORKDIR/mnt2
sudo mount -F pcfs $FAT_BLK $WORKDIR/mnt2

sudo cp -R $ROOT/boot $WORKDIR/mnt2/boot
sudo mkdir $WORKDIR/mnt2/EFI
sudo mkdir $WORKDIR/mnt2/EFI/BOOT
sudo mv $WORKDIR/mnt2/boot/loader64.efi $WORKDIR/mnt2/EFI/BOOT/BOOTAA64.EFI

sudo mkdir -p $WORKDIR/mnt2/platform/ARMH,sbbr/kernel/aarch64
sudo cp $ROOT/platform/ARMH,sbbr/kernel/aarch64/unix $WORKDIR/mnt2/platform/ARMH,sbbr/kernel/aarch64/unix
sudo mkdir -p $WORKDIR/mnt2/platform/armv8/kernel/aarch64
sudo cp $ROOT/platform/armv8/kernel/aarch64/unix $WORKDIR/mnt2/platform/armv8/kernel/aarch64/unix

sudo mkdir -p $WORKDIR/mnt2/platform/armv8/aarch64
sudo cp $WORKDIR/miniroot.gz $WORKDIR/mnt2/platform/armv8/aarch64/boot_archive

sudo umount $WORKDIR/mnt2
sudo rm -rf $WORKDIR/mnt2
mkdir -p $WORKDIR/usb-image

sudo lofiadm -d $USB_FILE
mv $USB_FILE $WORKDIR/usb-image/bootable.usb
