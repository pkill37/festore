# festore

REE-backed secure storage on the STM32MP157F-DK2.

## Motivation

Secure storage is an important primitive for building secure applications which can be built on trusted execution environments.

In today's security landscape it is attractive to encapsulate such a system in a trusted execution environment where it may run with higher security guarantees. Let's imagine a very simple crypto keystore offering only APIs for asymmetric keypair generation and asymmetric encryption. Such a naive keystore leveraging a TEE could consist of two components:

- a REE client application that communicates with the TEE
    - asking to generate an asymmetric key pair and store it tagged under some identifier string `tag`
    - asking to encrypt an arbitrary string using the key pair tagged by some string `tag`
- a TEE trusted application that responds to requests to
    - generate an asymmetric key pair (of your choice), storing them encrypted (using a symmetric encryption algorithm of your choice) in some secure storage tagged with some identifier `tag`
    - encrypt an arbitrary input string using the asymmetric key pair stored under the tag `tag`, and return the encrypted result back to the caller

We will develop such components for the OP-TEE and OpenSTLinux stack deployed on the STM32MP157F-DK2.

## Development Environment: STM32MP157F-DK2

We picked the STM32MP157F-DK2 board for development due to it being well supported on the OP-TEE and the Arm Trusted Firmware.

### Secure Boot Chain

![image](https://github.com/pkill37/festore/assets/180382/250e9485-3d49-4eb0-bfc3-2f5cf747230a)

1. The ROM code starts the processor in secure mode. It supports the FSBL authentication and offers authentication services to the FSBL.
2. The First stage bootloader (FSBL) is executed from the SYSRAM. Among other things, this bootloader initializes (part of) the clock tree and the DDR controller. Finally, the FSBL loads the second-stage bootloader (SSBL) into the DDR external RAM and jumps to it. The bootloader stage 2, so called TF-A BL2, is the Trusted Firmware-A (TF-A) binary used as FSBL on STM32MP15.
3. Second stage bootloader (SSBL) U-Boot is commonly used as a bootloader in embedded software and it is the one used on STM32MP15.
4. Linux® OS is loaded in DDR by U-Boot and executed in the non-secure context.
5. Secure OS / Secure monitor. The Cortex-A7 secure world supports OP-TEE secure OS which is loaded by TF-A BL2.

### Flash Layout

![image](https://github.com/pkill37/festore/assets/180382/598c2649-be5c-43f2-b61f-be3530324bc3)

### Build System

- Starter Package
- Developer Package
- Distribution Package

## Implementation

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
