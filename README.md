# SVXSpot: An SVXLink Analog Hotspot for the Raspberry Pi Zero

## Available Products

- [RF.Guru Analog Hotspot 70CM (UHF)](https://shop.rf.guru/products/2025-ce-041-u)  
  **100mW Power**

- [RF.Guru Analog Hotspot 2M (VHF)](https://shop.rf.guru/products/2025-ce-041-v)  
  **100mW Power** (Coming later this year)

---

## Repository Overview

This repository tracks the **main branch** of SVXLink. Most features are identical to the stable branch, with some notable new additions:

- **Encryption** for enhanced security.
- **Passwordless authentication** for ease of use. (Your device requests the certificate, we will confirm via the entered email adress in the configurtion)

After running the configurator, your **SVXReflector sysop** will need to sign your certificate. Once that's done, you're all set!

---

## SVXLink UHF - Bookworm Image

This image is designed for **UHF transceivers/hotspots**.  

### Default Configuration:
- **Frequency:** 434.925 MHz (FM Wide)
- **CTCSS:** 88.5 Hz (for both RX and TX)

### Download:
[Bookworm Image 2025-01-28](https://storage.googleapis.com/rf-guru/rpi-images/hotspot-main-2025-01-28.img.gz)  
*Compatible with Raspberry Pi Zero 2W, Raspberry Pi 4, and Raspberry Pi 5.*

### Additional Feature:
- Sending `D911#` will return the **IP address**, making it easy to access the dashboard.
- `hotspot-frequency` fast conifg to change frequency
- `hotspot-options` fast config to set options
- `hotspot-talkgroups` fast config to change/add default talkgroup and talkgroup to ctcss mapping
- `hotspot-volume` fast config option to set volume

---
