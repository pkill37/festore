#!/bin/sh
set -ex

workdir=$(pwd)
#STM32_Programmer_CLI -l usb
#
#[ ! -f "$workdir/Starter-Package/en.flash-stm32mp1-openstlinux-6-1-yocto-mickledore-mp1-v23-06-21.tar.gz" ] && exit 1
#
#cd Starter-Package/stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/images/stm32mp1
#tsv="flashlayout_st-image-weston/optee/FlashLayout_sdcard_stm32mp157f-dk2-optee.tsv"
#cat $tsv
#
#STM32_Programmer_CLI -c port=usb1 -w $tsv



. $workdir/Developer-Package/SDK/environment-setup-cortexa7t2hf-neon-vfpv4-ostl-linux-gnueabi
triplet_dirname=$(echo $CROSS_COMPILE | head -c -2)
cd "./Developer-Package/stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/sources/$triplet_dirname/optee-os-stm32mp-3.19.0-stm32mp-r1-r0/optee-os-stm32mp-3.19.0-stm32mp-r1"
export FIP_DEPLOYDIR_ROOT="$PWD/../../FIP_artifacts"
export FIP_DEPLOYDIR_FIP="$PWD/../deploy/fip"
make -f $PWD/../Makefile.sdk clean
cat $PWD/../Makefile.sdk
make -f $PWD/../Makefile.sdk \
	all \
	UBOOT_CONFIG=optee \
	UBOOT_DEFCONFIG=stm32mp15_trusted_defconfig \
	UBOOT_BINARY=u-boot.dtb \
	DEVICETREE="stm32mp157f-dk2" \
	CFG_EMBED_DTB_SOURCE_FILE="stm32mp157f-dk2" \
	CFG_WITH_USER_TA="y" \
	CFG_REE_FS="y"
ls -lah $FIP_DEPLOYDIR_FIP/

if="$FIP_DEPLOYDIR_FIP/fip-stm32mp157f-dk2-optee.bin"
of="$(readlink -f /dev/disk/by-partlabel/fip-a)"
while ! ls -lah $of ; do 
	echo "Please mount the microSD card"
	sleep 5
done
sudo dd if=$if of=$of bs=1M conv=fdatasync
