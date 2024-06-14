# festore

Secure storage of files backed by Arm TrustZone on the STM32MP157F-DK2.

## Motivation

Applications can have various secure storage requirements:
- Storing cryptographic material such as public and private keys for use in secure processes 
- Storing private user data in such a way that only the user can read it (secrecy)
- Storing data in such a way that it cannot be tampered with (non repudiation)
- ...

In today's security landscape it is attractive to encapsulate such secure storage systems in trusted execution environments (TEE) that run with higher security guarantees, without the security problems of typical rich execution environments (REE). A simple secure store offering an API for writing data could be architected between:

- a REE client application that communicates with the TEE whenever a secure storage service is required, for example to store some data buffer under some identifier string `tag`
- a TEE trusted application that responds to requests to store, tagged with `tag`, a data buffer encrypted in such a way that only the TEE can decrypt it later

## Development Environment: STM32MP157F-DK2

We picked the STM32MP157F-DK2 board for exploring secure storage on Arm TrustZone for its rich security feature set (secure boot, cryptographic engine, TPM integration). This board is well supported on the OP-TEE (a secure operating system designed for running on TEE) and the Arm Trusted Firmware (open source firmware for first stage bootloaders). It is also clear that ST offers excellent documentation, for getting started as well as diving deeper in the tech stack. 

### Hardware

The boot switches on the back of the motherboard allow to control the boot mode:

#### Forced USB boot for flashing
![image](https://github.com/pkill37/festore/assets/180382/632b09a6-2648-4804-8e24-1d30c6089434)

#### Boot from microSD card
![image](https://github.com/pkill37/festore/assets/180382/808f6d6c-ef1f-4b85-8695-b6e025dd8918)

### Flash Layout

The board has an eMMC interface with a microSD that is used as the main flash memory. Besides the boot ROM, it is where all software is stored. Flashing software on this board effectively means to write to the microSD card, according to a flash layout.

![image](https://github.com/pkill37/festore/assets/180382/598c2649-be5c-43f2-b61f-be3530324bc3)

### Software Packages

We used the following software packages which must be obtained independently on the ST website:

- Starter Package: `en.flash-stm32mp1-openstlinux-6-1-yocto-mickledore-mp1-v23-06-21.tar.gz`
- Developer Package
    - `en.sources-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.tar.gz`
    - `en.SDK-x86_64-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.tar.gz`

We use the starter package to flash an initial working version of the entire software stack on the board, which in ST's documentation also serves as an introduction to their platform and validation that the board is working. It consists of partition images, flash layout descriptions, binaries for OpenSTLinux, etc.

```
$ STM32_Programmer_CLI -l usb
$ tar xzvf en.flash-stm32mp1-openstlinux-6-1-yocto-mickledore-mp1-v23-06-21.tar.gz" ] && exit 1
$ cd stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/images/stm32mp1
$ STM32_Programmer_CLI -c port=usb1 -w flashlayout_st-image-weston/optee/FlashLayout_sdcard_stm32mp157f-dk2-optee.tsv
```

The developer package contains the SDK for all development on the Cortex-A, as well as an entire BSP with compiler toolchains, source code, device trees, etc. used for modifying components such as the U-Boot, TF-A, or OP-TEE OS. The SDK can be installed by running the SDK installation script:

```
$ tar xzvf en.SDK-x86_64-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.tar.gz
$ ./en.SDK-x86_64-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21/sdk/st-image-weston-openstlinux-weston-stm32mp1-x86_64-toolchain-4.2.1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.sh -d ./SDK
```

For our purposes we care to build individual software components (using the same build system and toolchains) that can be "overlayed" within the flashed partition images (which can be mounted and modified on a host computer). Alternatively the developer package can be used to build concrete partition images that can completely replaced the already flashed partition images, which can be necessary for small changes like configuration build options for the OP-TEE. Using the developer package boils down to sourcing an environment script that configures typical build system environment variables such as `$CROSS_COMPILE`, `$CC`, etc. These variables are picked up by the build system to build for the right targets.

```
$ . ./SDK/environment-setup-cortexa7t2hf-neon-vfpv4-ostl-linux-gnueabi
```

ST also describes something called the "distribution package" which is intended for final release and distribution in commercial products, not for convenient development and engineering. We did not use this because it did not concern us pedagogically.

### Secure Boot Chain

![image](https://github.com/pkill37/festore/assets/180382/91871288-ac10-4f30-b3ea-3c8a415cef4f)

- The ROM code starts the processor in secure mode and loads the First Stage Boot Loader (FSBL). It supports the FSBL authentication and offers authentication services to the FSBL.
- The FSBL is executed from a small 256KB SYSRAM. Among other things, this bootloader initializes (part of) the clock tree and the DDR controller.
- The FSBL loads the second-stage bootloader (SSBL), in the non secure world, into the DDR external RAM and jumps to it.
  - The SSBL runs in a wide RAM so it can implement complex features for loading the Linux kernel and the userspace. U-Boot is commonly used as a Linux bootloader in embedded systems.
    - The Linux kernel is started (in non-secure context) in the external memory and it initializes all the peripheral drivers that are needed on the platform. Then the kernel hands control to the user space starting the init process.
  - The FSBL starts the secure monitor and the OP-TEE OS.

Attached in `boot_log.txt` is a copy of the entire boot log found in the serial port of the device. The `stlink.sh` contains a small script to get these logs by connecting to the ST-LINK serial port which is available through a front-facing micro USB interface on the board.

## Implementation

The focus of this work is on the interaction between Trusted Applications (running on the secure world) and Host Applications (running on the non secure world). We develop [User Mode Trusted Applications](https://optee.readthedocs.io/en/latest/architecture/trusted_applications.html#user-mode-trusted-applications), stored on the REE filesystem.

The TA consist of ELF files, named as the designated UUID of the TA and with the suffix `.ta`. They are built separately from the OP-TEE, and are signed with the key from the build of the original OP-TEE core blob. Because the TAs are signed, they are able to be stored in the untrusted REE filesystem, and `tee-supplicant` will take care of passing them to be checked and loaded by the OP-TEE.

We develop a simple demo based on the [OP-TEE pedagogical applications](https://github.com/linaro-swg/optee_examples).

### OP-TEE OS

For our goals and requirements, the OP-TEE OS itself must be configured with special build system configuration options, and recompiled into the FIP image to be flashed on the FIP partition.

```
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
```

Specifically we cared to configure:
- `CFG_REE_FS` to enable the file storage initiated by the TEE on the REE
- `CFG_WITH_USER_TA` to enable user loaded trusted applications (otherwise your host applications will not find your trusted applications)
- `CFG_EMBED_DTB_SOURCE_FILE` and `DEVICETREE` to minimally point to our board rather than the whole ecosystem of boards

### OP-TEE Trusted Application

Trusted application is in `festore/ta/`.

### OpenSTLinux Client Application

Client application is in `festore/host/`.

### Demonstration

The REE host application is deployed under `/usr/bin/optee_festore` which can be analyzed with strace:

```
root@stm32mp1:~# strace optee_festore
...
```

The files are stored under `/var/lib/tee` but in encrypted fashion. The data can only be decrypted by the TEE, thus it is completely protected from the REE (non secure world).

```
root@stm32mp1:/var/lib/tee# ls -lah
total 72K
drwxrwx---  2 root tee  4.0K Mar  6 07:53 .
drwxr-xr-x 14 root root 4.0K Mar  3 09:49 ..
-rw-------  1 tee  tee  4.2K Mar  5 14:22 0
-rw-------  1 tee  tee   16K Mar  5 14:22 1
-rw-------  1 tee  tee   24K Mar  6 07:53 2
-rw-------  1 tee  tee   16K Mar  6 07:53 dirf.db

root@stm32mp1:/var/lib/tee# hexdump -C 0
00000000  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000040  00 00 00 00 c2 a2 2b fb  bc 93 66 bd f8 f1 9f b8  |......+...f.....|
00000050  c4 4a 74 c3 fc 15 6a 82  e3 d0 f2 5a e3 7e 40 9c  |.Jt...j....Z.~@.|
00000060  b5 96 1a 0f 64 07 28 6f  fc 3d f9 0b 9f 4f f7 31  |....d.(o.=...O.1|
00000070  39 01 90 61 9d 6c 2a 16  e3 8e 49 f9 6c 62 3d 98  |9..a.l*...I.lb=.|
00000080  2f e9 68 a0 01 00 00 00  00 00 00 00 00 00 00 00  |/.h.............|
00000090  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00001040  00 00 09 4c 49 31 fd b2  f2 af 41 7c 9e 03 22 a9  |...LI1....A|..".|
00001050  71 60 06 e8 21 1f e9 01  7f 67 1a c6 e3 25 13 00  |q`..!....g...%..|
00001060  ac ca 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00001070  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00001080  00 00 00 00                                       |....|
00001084
```

### Conclusion

Lorem ipsum
