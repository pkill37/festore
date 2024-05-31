# tztpm

ARM TrustZone secure boot, assisted by discrete TPM

## Design

- Store PCR in TPM
- Ask TPM to combine PCRs and sign it

## Architecture

- Boot OP-TEE in secure world
  - TPM Trusted Application 
- Boot OpenSTLinux in normal world
