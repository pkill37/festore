#!/bin/sh
set -ex

STM32_Programmer_CLI -l usb

workdir=$(pwd)
[ ! -f "$workdir/Starter-Package/en.flash-stm32mp1-openstlinux-6-1-yocto-mickledore-mp1-v23-06-21.tar.gz" ] && exit 1

cd Starter-Package/stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/images/stm32mp1
tsv="flashlayout_st-image-weston/optee/FlashLayout_sdcard_stm32mp157f-dk2-optee.tsv"
cat $tsv

STM32_Programmer_CLI -c port=usb1 -w $tsv
