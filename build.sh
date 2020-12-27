#!/bin/bash

kernels="4.19 5.4 5.10"

for kernel in $kernels; do

if [ ! -f "./kernel-$kernel/out/arch/x86/boot/bzImage" ]; then echo "The kernel $kernel has to be built first"; exit 1; fi

done

if ( ! test -z {,} ); then echo "Must be ran with \"sudo bash\""; exit 1; fi
if [ $(whoami) != "root" ]; then echo "Please run with sudo"; exit 1; fi
if [ -z $(which cgpt) ]; then echo "The cgpt package/binary has to be installed first"; exit 1; fi
if [ ! -f "$1" ]; then echo "ChromeOS recovery image $1 not found"; exit 1; fi
if [ ! $(dd if="$1" bs=1 count=4 status=none | od -A n -t x1 | sed 's/ //g') == '33c0fa8e' ] || [ $(cgpt show -i 12 -b "$1") -eq 0 ] || [ $(cgpt show -i 13 -b "$1") -gt 0 ] || [ ! $(cgpt show -i 3 -l "$1") == 'ROOT-A' ]; then echo "$1 is not a valid ChromeOS recovery image"; fi

if mountpoint -q ./chroot/dev/shm; then umount ./chroot/dev/shm; fi
if mountpoint -q ./chroot/dev; then umount ./chroot/dev; fi
if mountpoint -q ./chroot/sys; then umount ./chroot/sys; fi
if mountpoint -q ./chroot/proc; then umount ./chroot/proc; fi
if mountpoint -q ./chroot/out; then umount ./chroot/out; fi
if [ -d ./chroot ]; then rm -r ./chroot; fi
if [ -d ./out ]; then rm -r ./out; fi

mkdir -p ./chroot/out ./out
chmod 0777 ./out

recovery_image=$(losetup --show -fP "$1")
mount -o ro "$recovery_image"p3 ./out
cp -a ./out/* ./chroot/
umount ./out
mkdir ./chroot/home/chronos/image
dd if="$recovery_image"p12 of=./chroot/home/chronos/image/efi.img bs=1M
cp -r ./efi-mods ./chroot/home/chronos/image/
chown -R 1000:1000 ./chroot/home/chronos/image
losetup -d "$recovery_image"

chmod 0777 ./chroot/home/chronos
rm ./chroot/etc/resolv.conf
echo 'nameserver 8.8.4.4' > ./chroot/etc/resolv.conf
echo 'chronos ALL=(ALL) NOPASSWD: ALL' > ./chroot/etc/sudoers.d/95_cros_base

mkdir ./chroot/home/chronos/brunch
cp ./scripts/chromeos-install.sh ./chroot/home/chronos/brunch/
chmod 0755 ./chroot/home/chronos/brunch/chromeos-install.sh
chown -R 1000:1000 ./chroot/home/chronos/brunch

mkdir ./chroot/home/chronos/initramfs
cp ./scripts/brunch-init ./chroot/home/chronos/initramfs/init
cp -r ./bootsplash ./chroot/home/chronos/initramfs/
chmod 0755 ./chroot/home/chronos/initramfs/init
chown -R 1000:1000 ./chroot/home/chronos/initramfs

mkdir ./chroot/home/chronos/rootc
ln -s kernel-5.4 ./chroot/home/chronos/rootc/kernel
cp -r ./packages ./chroot/home/chronos/rootc/
cp -r ./patches ./chroot/home/chronos/rootc/
chmod -R 0755 ./chroot/home/chronos/rootc/patches
chown -R 1000:1000 ./chroot/home/chronos/rootc

for kernel in $kernels; do

mkdir -p ./chroot/home/chronos/kernel
cp -r ./kernel-"$kernel" ./chroot/tmp/kernel
cd ./chroot/tmp/kernel
kernel_version="$(file ./out/arch/x86/boot/bzImage | cut -d' ' -f9)"
cp ./out/arch/x86/boot/bzImage ../../home/chronos/rootc/kernel-"$kernel"
make O=out INSTALL_MOD_PATH=../../../home/chronos/kernel modules_install
rm ../../home/chronos/kernel/lib/modules/"$kernel_version"/build
rm ../../home/chronos/kernel/lib/modules/"$kernel_version"/source
cp -r ./out/headers ../../home/chronos/kernel/lib/modules/"$kernel_version"/build
mkdir -p ../../home/chronos/kernel/usr/src
ln -s /lib/modules/"$kernel_version"/build ../../home/chronos/kernel/usr/src/linux-headers-"$kernel_version"
cd ../../..

if [ "$2" != "skip" ]; then

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ]; then

cp -r ./chroot/home/chronos/kernel/lib/modules ./chroot/home/chronos/kernel/lib/orig
cp -r ./external-drivers/backport-iwlwifi-core56 ./chroot/tmp/backport-iwlwifi
cd ./chroot/tmp/backport-iwlwifi
make defconfig-iwlwifi-public
make -j$(($(nproc)-1))
make KLIB=../../../home/chronos/kernel install
cd ../../..
rm -r ./chroot/tmp/backport-iwlwifi
rm -r ./chroot/home/chronos/kernel/lib/modules/"$kernel_version"/build
rm -r ./chroot/home/chronos/kernel/lib/modules/"$kernel_version"/kernel
mv ./chroot/home/chronos/kernel/lib/modules/"$kernel_version" ./chroot/home/chronos/kernel/lib/orig/"$kernel_version"/iwlwifi_backport
rm -r ./chroot/home/chronos/kernel/lib/modules
mv ./chroot/home/chronos/kernel/lib/orig ./chroot/home/chronos/kernel/lib/modules

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ] || [ "$kernel" == "5.10" ]; then

cp -r ./external-drivers/rtbth ./chroot/tmp/
cd ./chroot/tmp/rtbth
make -j$(($(nproc)-1))
cp ./rtbth.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/rtbth.ko
cd ../../..
rm -r ./chroot/tmp/rtbth

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ]; then

cp -r ./external-drivers/rtl8188eu ./chroot/tmp/
cd ./chroot/tmp/rtl8188eu
make -j$(($(nproc)-1)) modules
cp ./8188eu.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/rtl8188eu.ko
cd ../../..
rm -r ./chroot/tmp/rtl8188eu

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ]; then

cp -r ./external-drivers/rtl8723bu ./chroot/tmp/
cd ./chroot/tmp/rtl8723bu
make -j$(($(nproc)-1)) modules
cp ./8723bu.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/rtl8723bu.ko
cd ../../..
rm -r ./chroot/tmp/rtl8723bu

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ] || [ "$kernel" == "5.10" ]; then

cp -r ./external-drivers/rtl8723de ./chroot/tmp/
cd ./chroot/tmp/rtl8723de
make -j$(($(nproc)-1))
cp ./rtl8723de.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/rtl8723de.ko
cd ../../..
rm -r ./chroot/tmp/rtl8723de

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ]; then

cp -r ./external-drivers/rtl8812au ./chroot/tmp/
cd ./chroot/tmp/rtl8812au
make -j$(($(nproc)-1)) modules
cp ./88XXau.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/rtl8812au.ko
cd ../../..
rm -r ./chroot/tmp/rtl8812au

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ] || [ "$kernel" == "5.10" ]; then

cp -r ./external-drivers/rtl8821ce ./chroot/tmp/
cd ./chroot/tmp/rtl8821ce
make -j$(($(nproc)-1)) modules
cp ./8821ce.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/rtl8821ce.ko
cd ../../..
rm -r ./chroot/tmp/rtl8821ce

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ] || [ "$kernel" == "5.10" ]; then

cp -r ./external-drivers/rtl88x2bu ./chroot/tmp/
cd ./chroot/tmp/rtl88x2bu
make -j$(($(nproc)-1)) modules
cp ./88x2bu.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/rtl88x2bu.ko
cd ../../..
rm -r ./chroot/tmp/rtl88x2bu

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ] || [ "$kernel" == "5.10" ]; then

cp -r ./external-drivers/broadcom-wl ./chroot/tmp/
cd ./chroot/tmp/broadcom-wl
make -j$(($(nproc)-1))
cp ./wl.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/broadcom_wl.ko
cd ../../..
rm -r ./chroot/tmp/broadcom-wl

fi

if [ "$kernel" == "4.19" ] || [ "$kernel" == "5.4" ] || [ "$kernel" == "5.10" ]; then

cp -r ./external-drivers/acpi_call ./chroot/tmp/
cd ./chroot/tmp/acpi_call
make -j$(($(nproc)-1))
cp ./acpi_call.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/acpi_call.ko
cd ../../..
rm -r ./chroot/tmp/acpi_call

fi

if [ "$kernel" == "5.4" ] || [ "$kernel" == "5.10" ]; then

cp -r ./external-drivers/ipts ./chroot/tmp/
cd ./chroot/tmp/ipts
make -j$(($(nproc)-1))
cp ./ipts.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/ipts.ko
cd ../../..
rm -r ./chroot/tmp/ipts

fi

#cp -r ./external-drivers/mbp2018-bridge ./chroot/tmp/
#cd ./chroot/tmp/mbp2018-bridge
#make -j$(($(nproc)-1))
#cp ./bce.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/bce.ko
#cd ../../..
#rm -r ./chroot/tmp/mbp2018-bridge

#cp -r ./external-drivers/mbp2018-spi ./chroot/tmp/
#cd ./chroot/tmp/mbp2018-spi
#make -j$(($(nproc)-1))
#cp ./apple-ibridge.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/apple-ibridge.ko
#cp ./apple-ib-tb.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/apple-ib-tb.ko
#cp ./apple-ib-als.ko ../../../chroot/home/chronos/kernel/lib/modules/"$kernel_version"/apple-ib-als.ko
#cd ../../..
#rm -r ./chroot/tmp/mbp2018-spi

fi

cd ./chroot/home/chronos/kernel
tar zcf ../rootc/packages/kernel-"$kernel_version".tar.gz * --owner=0 --group=0
cd ../../../..
rm -r ./chroot/home/chronos/kernel
rm -r ./chroot/tmp/kernel

done

mkdir -p ./chroot/home/chronos/rootc/lib ./chroot/home/chronos/rootc/usr/share/alsa
cp -r ./alsa-ucm-mods ./chroot/home/chronos/rootc/usr/share/alsa/ucm
cd ./chroot/home/chronos/rootc/lib
git clone --depth=1 -b master git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git firmware
cd ./firmware
rm -rf ./.git
rm -rf ./bnx2x
rm -rf ./dpaa2
rm -rf ./liquidio
rm -rf ./mellanox
rm -rf ./netronome
rm -rf ./qcom
rm -rf ./qed
rm -rf ./ti-connectivity
cd ../../../../../..
cp -r ./firmware-mods/* ./chroot/home/chronos/rootc/lib/firmware/
chown -R 1000:1000 ./chroot/home/chronos/rootc

mount --bind ./out ./chroot/out
mount -t proc none ./chroot/proc
mount -t sysfs none ./chroot/sys
mount -t devtmpfs none ./chroot/dev
mount -t tmpfs -o mode=1777,nosuid,nodev,strictatime tmpfs ./chroot/dev/shm

cp ./scripts/build-init ./chroot/init
chroot --userspec=1000:1000 ./chroot /init

umount ./chroot/dev/shm
umount ./chroot/dev
umount ./chroot/sys
umount ./chroot/proc
umount ./chroot/out
rm -r ./chroot