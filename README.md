# tzfe

A crypto keystore, fundamentally, serves as a secure storage mechanism for cryptographic keys for various cryptographic operations. The primary functions and features of a rudimentary crypto keystore may include:

- Secure Storage: secure repository for cryptographic keys, ensuring that they are stored in an encrypted form and protected from unauthorized access.
- Key Management: key generation, deletion, etc.
- Cryptographic Operations: encryption and decryption directly within the keystore environment, enhancing security by minimizing the exposure of keys.

In today's security landscape it is attractive to encapsulate such a system in a trusted execution environment where it may run with higher security guarantees. Let's imagine a very simple crypto keystore offering only APIs for asymmetric keypair generation and asymmetric encryption. Such a naive keystore leveraging a TEE could consist of two components:

- a REE client application that communicates with the TEE
    - asking to generate an asymmetric key pair and store it tagged under some identifier string `tag`
    - asking to encrypt an arbitrary string using the key pair tagged by some string `tag`
- a TEE trusted application that responds to requests to
    - generate an asymmetric key pair (of your choice), storing them encrypted (using a symmetric encryption algorithm of your choice) in some secure storage tagged with some identifier `tag`
    - encrypt an arbitrary input string using the asymmetric key pair stored under the tag `tag`, and return the encrypted result back to the caller

We will develop such components for the OP-TEE and OpenSTLinux stack deployed on the STM32MP157F-DK2.
