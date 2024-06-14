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

- https://wiki.st.com/stm32mpu/wiki/STM32MP15_Discovery_kits_-_Starter_Package
- https://wiki.st.com/stm32mpu/wiki/STM32MP1_Developer_Package
- https://wiki.st.com/stm32mpu/wiki/How_to_develop_an_OP-TEE_Trusted_Application
- https://wiki.st.com/stm32mpu/wiki/How_to_configure_OP-TEE
- https://wiki.st.com/stm32mpu/wiki/STM32MP1_Developer_Package
- https://wiki.st.com/stm32mpu/wiki/Boot_chain_overview

### Hardware

The boot switches on the back of the motherboard allow to control the boot mode:

#### Forced USB boot for flashing
![image](https://github.com/pkill37/festore/assets/180382/632b09a6-2648-4804-8e24-1d30c6089434)

#### Boot from microSD card
![image](https://github.com/pkill37/festore/assets/180382/808f6d6c-ef1f-4b85-8695-b6e025dd8918)

### Flash Layout

The board has an eMMC interface with a microSD that is used as the main flash memory. Besides the boot ROM, it is where all software is stored. Flashing software on this board effectively means to write to the microSD card, according to a flash layout.

![image](https://github.com/pkill37/festore/assets/180382/598c2649-be5c-43f2-b61f-be3530324bc3)

When the board configuration switches are set to

![image](https://github.com/pkill37/festore/assets/180382/7cedb9ad-b423-4a6c-b8a1-b960563de30c)


### Software Packages

We used the following software packages as described by ST:

- Starter Package: `en.flash-stm32mp1-openstlinux-6-1-yocto-mickledore-mp1-v23-06-21.tar.gz`
- Developer Package
    - `en.sources-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.tar.gz`
    - `en.SDK-x86_64-stm32mp1-openstlinux-6.1-yocto-mickledore-mp1-v23.06.21.tar.gz`

We use the starter package to flash an initial working version of the entire software stack on the board, which in ST's documentation also serves as an introduction to their platform and validation that the board is working. It consists of partition images, flash layout descriptions, binaries for OpenSTLinux, etc.

The developer package contains the SDK for all development on the Cortex-A, as well as an entire BSP with compiler toolchains, source code, device trees, etc. used for modifying components such as the U-Boot, TF-A, or OP-TEE OS.

For our purposes we care to build individual software components (using the same build system and toolchains) that can be "overlayed" within the flashed partition images (which can be mounted and modified on a host computer). Alternatively the developer package can be used to build concrete partition images that can completely replaced the already flashed partition images, which can be necessary for small changes like configuration build options for the OP-TEE.

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

## Results

Include the boot loader sequence
Show the strace output
Mention the role of /usr/lib/libtec.so
The part where communication with the TEE starts
Copy and paste the logs from ./stlink.sh
Include the boot output
Point this out in the report -> /var/lib/tee"

**Strace Analysis:** Use the `strace` tool to trace system calls and signals during the boot process and communication with the TEE
**stlink.sh Logs:** Paste and anaylise the logs from `stlink.sh`
**Boot Output:** Include the output generated during the STM32's boot sequence, and early stage interactions with OP-TEE
**/var/lib/tee:** Anaylise and mention /var/lib/tee 

## Conclusion
