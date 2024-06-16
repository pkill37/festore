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

The STM32MP157F-DK2 Discovery kits packages are delivered fully assembled, and a USB Type-C cable is also included for USB programming. An additional micro USB cable is necessary for connecting to the ST-LINK debugging serial port.

![image](https://github.com/pkill37/festore/assets/180382/fa9bb707-a38e-4c66-a8d2-7da609141619)

1. MB1272 motherboard: STM32MP157x 12x12, PMIC, DDR3
2. MicroSD card slot
3. 2x USB Type-A (host) for mouse, keyboard or other USB driver
4. 2x USB Type-A (host)
5. USB micro-B (ST-LINK/V2-1) for PC virtual COM port and debug
6. Reset button
7. Ethernet → Network
8. USB Type-C (power 5V-3A)

The boot switches on the back of the motherboard allow to control what happens when power is given to boot the system:

#### Forced USB boot for flashing
![image](https://github.com/pkill37/festore/assets/180382/632b09a6-2648-4804-8e24-1d30c6089434)

#### Boot system from microSD card
![image](https://github.com/pkill37/festore/assets/180382/808f6d6c-ef1f-4b85-8695-b6e025dd8918)

### Flash Layout

The board has an SDMMC interface with a microSD that is used as the main flash memory. Besides the boot ROM, it is where all software is stored. Flashing software on this board effectively means to write to the microSD card, according to a flash layout. It follows the following partitioning scheme:

![image](https://github.com/pkill37/festore/assets/180382/598c2649-be5c-43f2-b61f-be3530324bc3)

The more important partitions include:

- **userfs:** The user's home directory.
- **rootfs:** Linux root file system contains all user space binaries (executable, libraries, and so on), and kernel modules
- **bootfs:** The boot file system contains software relevant for booting the system after the second stage bootloader
  - optionally an init RAM file system, which can be copied to the external RAM and used by Linux before mounting a fatter rootfs
  - Linux kernel device tree
  - Linux kernel U-Boot image
- **fip:** The TF-A firmware image package (FIP) is a binary file that encapsulates several binaries that will be loaded by TF-A BL2:
  - the second stage boot loader (SSBL):
  - U-Boot binary
  - U-Boot device tree blob
  - the OP-TEE
- **fsbl**: The first stage boot loader is Arm Trusted Firmware (TF-A).

On other boards there are eMMC interfaces where the physical hardware boot partitions can be used for the FSBL.

When you mount it in a Linux system you should see the following partition tree:

```
$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    1  14.8G  0 disk 
├─sda1        8:1    1   256K  0 part 
├─sda2        8:2    1   256K  0 part 
├─sda3        8:3    1   256K  0 part 
├─sda4        8:4    1   256K  0 part 
├─sda5        8:5    1     4M  0 part 
├─sda6        8:6    1     4M  0 part 
├─sda7        8:7    1   512K  0 part 
├─sda8        8:8    1    64M  0 part /media/fabio/bootfs
├─sda9        8:9    1    16M  0 part /media/fabio/vendorfs
├─sda10       8:10   1     4G  0 part /media/fabio/rootfs
└─sda11       8:11   1  10.7G  0 part /media/fabio/userfs
```

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
```

Specifically we cared to configure:
- `CFG_REE_FS` to enable the file storage initiated by the TEE on the REE
- `CFG_WITH_USER_TA` to enable user loaded trusted applications (otherwise your host applications will not find your trusted applications)
- `CFG_EMBED_DTB_SOURCE_FILE` and `DEVICETREE` to minimally point to our board rather than the whole ecosystem of boards

After building we must flash the fip partition image on the mounted microSD card:

```
if="$FIP_DEPLOYDIR_FIP/fip-stm32mp157f-dk2-optee.bin"
of="$(readlink -f /dev/disk/by-partlabel/fip-a)"
sudo dd if=$if of=$of bs=1M conv=fdatasync
```

### OpenSTLinux Client Application

The client application for OpenSTLinux interacts with a Trusted Execution Environment (TEE) for secure storage services. The application demonstrates how to prepare a session with the TEE, write an object into secure storage, and then terminate the session.

#### TEE Session and Context

There is a helper structure `struct test_ctx` to keep track of TEE session and context.

```
struct test_ctx {
    TEEC_Context ctx;
    TEEC_Session sess;
};
```

This is used in the basic flow of dealing with the TEE session and context:

- `prepare_tee_session`:  initializes the TEE context and opens a session with the TA
	- `TEEC_InitializeContext`: establishes a connection to the TEE.
	- `TEEC_OpenSession`: opens a session with the specified TA using its UUID.
- `terminate_tee_session`: closes the session and finalizes the context to release TEE resources.
  	- `TEEC_CloseSession`: close the session with the TA
  	- `TEEC_FinalizeContext`: close the connection with the TEE

#### Prepare Operation Parameters

A big part of writing applications for OP-TEE is preparing the operation before issuing the TEE command.

```
TEEC_Operation op;  memset(&op, 0, sizeof(op));
op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_INPUT, TEEC_MEMREF_TEMP_INPUT, TEEC_NONE, TEEC_NONE);
op.params[0].tmpref.buffer = id;
op.params[0].tmpref.size = id_len;
op.params[1].tmpref.buffer = data;
op.params[1].tmpref.size = data_len;
```

- `op.paramTypes` specifies the types of parameters being passed to the TEE command which is set to the macro `TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_INPUT, TEEC_MEMREF_TEMP_INPUT, TEEC_NONE, TEEC_NONE)` that defines the types of the four parameters. In this case:
	- The first parameter is a temporary memory reference for input.
	- The second parameter is also a temporary memory reference for input.
	- The third and fourth parameters are not used (TEEC_NONE).
- `op.params` holds the parameters in temporary buffers together with its size.
	- `op.params[0].tmpref.buffer = id` sets the buffer for the first parameter to the object identifier.
	- `op.params[1].tmpref.buffer = data` sets the buffer for the second parameter to the data to be written.

#### Invoke Command

Finally the command is issued to the TEE via the shared library `/usr/lib/teec.so` which in turn talks to the Linux kernel driver:

```
uint32_t origin;
TEEC_Result res = TEEC_InvokeCommand(&ctx->sess, TA_FESTORE_CMD_WRITE_OBJECT, &op, &origin);
if (res != TEEC_SUCCESS)
    printf("Command WRITE_RAW failed: 0x%x / %u\n", res, origin);
```

- `TEEC_InvokeCommand(&ctx->sess, TA_FESTORE_CMD_WRITE_OBJECT, &op, &origin)` Invokes the TEE command identified by `TA_FESTORE_CMD_WRITE_OBJECT` using the global session with the parameters specified in `op`. 
- if the command invocation was not successful, the response code and the origin of the error are printed for debugging

### OP-TEE Trusted Application

A trusted application in OP-TEE can be seen as a series of entrypoints that can be hooked by handler functions:
- Create entrypoint
- Destroy entrypoint
- Open session entrypoint
- Invoke command entrypoint
- Close session entrypoint

Many of these entrypoints are rather thin boilerplate functions that are rarely useful, except for `TA_InvokeCommandEntryPoint` which serves as a dispatcher for handling calls to the TA. We have only one command for the demonstration, therefore the dispatching is a rather short switch statement.

```
TEE_Result TA_InvokeCommandEntryPoint(void __maybe_unused *session, uint32_t cmd_id, uint32_t param_types, TEE_Param params[4])
{
    switch (cmd_id) {
    case TA_FESTORE_CMD_WRITE_OBJECT:
        return write_object(param_types, params);
    default:
        return TEE_ERROR_BAD_PARAMETERS;
    }
}
```

Thus the focus is again on the `write_object` method that handles the command invocation on the TEE.

#### Parameter Verification

OP-TEE gives an interface that allows ensuring the parameter types given to the TA are the expected types. In this case it expects two input memory references: a string for the object ID and another for its actual data to be stored.

```
const uint32_t exp_param_types =
    TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
                    TEE_PARAM_TYPE_MEMREF_INPUT,
                    TEE_PARAM_TYPE_NONE,
                    TEE_PARAM_TYPE_NONE);

if (param_types != exp_param_types)
    return TEE_ERROR_BAD_PARAMETERS;
```

#### Parameter Memory Allocation

OP-TEE operates in the secure world which is separate from the non secure world. The parameters passed to the TA from the non-secure world need to be handled carefully to maintain security and integrity. Directly using the pointers provided in the parameters could expose the TA to vulnerabilities such as:

- Buffer Overflow/Underflow: Directly accessing buffers without validation could lead to memory corruption.
- Non-Secure Memory Access: Accessing non-secure memory directly could introduce security risks where secure data might get exposed or non-secure data might be improperly trusted.

Allocating memory within the TA ensures that the data is securely handled within the trusted memory space. Thus in the TA command invocation we allocate memory for the object ID and the data just before writing to storage.

```
size_t obj_id_sz = params[0].memref.size;
char *obj_id = TEE_Malloc(obj_id_sz, 0);
if (!obj_id)
    return TEE_ERROR_OUT_OF_MEMORY;
TEE_MemMove(obj_id, params[0].memref.buffer, obj_id_sz);

size_t data_sz = params[1].memref.size;
char *data = TEE_Malloc(data_sz, 0);
if (!data)
    return TEE_ERROR_OUT_OF_MEMORY;
TEE_MemMove(data, params[1].memref.buffer, data_sz);
```

#### Creating Persistent Object

The data we want to write should be persisted across TA instances and reboots. This is what is called a persistent object and it has a specific API, distinct from the transient objects API which supports temporary objects that are typically used for temporary cryptographic operations where the objects should not be retained.


To create a persistent object the method `TEE_CreatePersistentObject` is used:

```
obj_data_flag = TEE_DATA_FLAG_ACCESS_READ |
                TEE_DATA_FLAG_ACCESS_WRITE |
                TEE_DATA_FLAG_ACCESS_WRITE_META |
                TEE_DATA_FLAG_OVERWRITE;

res = TEE_CreatePersistentObject(TEE_STORAGE_PRIVATE_REE,
                                 obj_id, obj_id_sz,
                                 obj_data_flag,
                                 TEE_HANDLE_NULL,
                                 NULL, 0,
                                 &object);
if (res != TEE_SUCCESS) {
    EMSG("TEE_CreatePersistentObject failed 0x%08x", res);
    TEE_Free(obj_id);
    TEE_Free(data);
    return res;
}
```

Noteworthy are:
- The data access flags
	- `TEE_DATA_FLAG_ACCESS_READ`: The object is opened with the read access right. This allows the Trusted Application to call the function `TEE_ReadObjectData`.
	- `TEE_DATA_FLAG_ACCESS_WRITE`: The object is opened with the write access right. This allows the Trusted Application to call the functions `TEE_WriteObjectData` and `TEE_TruncateObjectData`.
	- `TEE_DATA_FLAG_ACCESS_WRITE_META`: The object is opened with the write-meta access right. This allows the Trusted Application to call the functions `TEE_CloseAndDeletePersistentObject` and `TEE_RenamePersistentObject`.
 	- `TEE_DATA_FLAG_OVERWRITE`: If this flag is present and the object exists, then the object is deleted and re-created as an atomic operation: that is the TA sees either the old object or the new one. If the flag is absent and the object exists, then the function SHALL return `TEE_ERROR_ACCESS_CONFLICT`.
- `TEE_STORAGE_PRIVATE_REE` determines that the REE's filesystem is used as a storage backend, which for security tells OP-TEE to encrypt the data in such a way that only the TA can read it thus being safe from attackers in the REE.
- `TEE_HANDLE_NULL` is specifying that there is no handle on a persistent object to take attributes from because it is a pure data object.

#### Write Data to Secure Storage

Finally we write the persistent object and cleanup appropriately:

```
res = TEE_WriteObjectData(object, data, data_sz);
if (res != TEE_SUCCESS) {
    EMSG("TEE_WriteObjectData failed 0x%08x", res);
    TEE_CloseAndDeletePersistentObject1(object);
} else {
    TEE_CloseObject(object);
}
TEE_Free(obj_id);
TEE_Free(data);
return res;
```

### Demonstration

The files are stored securely in the REE under `/var/lib/tee`.  All normal world files are integrity protected and encrypted as configured by our code. A directory file, `/var/lib/tee/dirf.db`, lists all the objects that are in the secure storage.

The REE client application is deployed under `/usr/bin/optee_festore` which can be analyzed with strace to follow the calls up to the Linux kernel driver.

```
root@stm32mp1:~# strace optee_festore
...
```

After running the client application we should see a new file in `/var/lib/tee`:

```
root@stm32mp1:/var/lib/tee# ls -lah
total 72K
drwxrwx---  2 root tee  4.0K Mar  6 07:53 .
drwxr-xr-x 14 root root 4.0K Mar  3 09:49 ..
-rw-------  1 tee  tee  4.2K Mar  5 14:22 0
-rw-------  1 tee  tee   16K Mar  5 14:22 1
-rw-------  1 tee  tee   24K Mar  6 07:53 2
-rw-------  1 tee  tee   16K Mar  6 07:53 dirf.db

root@stm32mp1:/var/lib/tee# hexdump -C 2
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

In short we have implemented an application that demonstrates a simple secure storage mechanism that leverages the REE filesystem as a "backend" for actually storing the data, but its encryption and integrity protection is done in the TEE trusted application.

Alternatively, instead of using the REE's filesystem, future work could be to leverage RPMB secure storage. The RPMB is a special area of the eMMC flash that provides:

1. **Replay Protection:** To prevent replay attacks, each write must include a monotonically increasing counter (stored in the secure memory) which must be higher than the previous write's counter, otherwise rejecting the write.
2. **Authentication:** Each write has a MAC to ensure the data was not modified in transit, which can be verified when reading as well.
3. **Secure Key Provisioning:** The keys used for the MAC generation are either provisioned securely during manufacturing, or isolated in secure hardware such as a discrete TPM.
