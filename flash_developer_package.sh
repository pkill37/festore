#!/bin/sh
set -ex

STM32_Programmer_CLI -l usb

workdir=$(pwd)

[ ! -f "$workdir/Developer-Package/en.SDK-x86_64-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.tar.gz" ] && exit 1
[ ! -f "$workdir/Developer-Package/en.sources-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.tar.gz" ] && exit 1

if [ ! -d $workdir/Developer-Package/SDK ]; then
	cd Developer-Package/en.SDK-x86_64-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/sdk
	./st-image-weston-openstlinux-weston-stm32mp1-x86_64-toolchain-4.2.1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.sh -d $workdir/Developer-Package/SDK
fi

if [ ! -d $workdir/Developer-Package/stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21 ]; then
	cd $workdir/Developer-Package
	tar xvf en.sources-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.tar.gz
fi

. $workdir/Developer-Package/SDK/environment-setup-cortexa7t2hf-neon-vfpv4-ostl-linux-gnueabi

cp -rav $workdir/fekeystore/ "$workdir/Developer-Package/stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/sources/$(echo $CROSS_COMPILE | head -c -2)"

cd $workdir/fekeystore
$CC fekeystore.c -o fekeystore

file fekeystore
strings fekeystore | grep -i fabio

#umount /media/fabio/bootfs
