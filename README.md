# SVXSpot: An SVXLink Analog Hotspot for the Raspberry Pi Zero

## Available Products

- [RF.Guru Analog Hotspot/Transceiver](https://shop.rf.guru/collections/hotspot)  
  **300-500mW Power**

---

## Repository Overview

This repository tracks the **release branch** of SVXLink.

After running the configurator, your **SVXReflector sysop** will need to sign your certificate. Once that's done, you're all set!

---

## SVXLink - Bookworm Image

This image is designed for **UHF and VHF transceivers/hotspots**.  

### Default Configuration:
- **Frequency UHF:** 434.925 MHz (FM Narrow)
- **Frequency VHF:** 145.925 MHz (FM Narrow)
- **CTCSS on the INPUT:** 88.5 Hz
- **CTCSS on the OUTPUT:** 250.3 Hz

### Download:
[Bookworm Image 2025-12-05](https://storage.googleapis.com/rf-guru/rpi-images/hotspot-2025-12-05.img.gz)  
*Compatible with Raspberry Pi Zero 2W*

### Additional Features:
- Sending `D911#` will return the **IP address**, making it easy to access the dashboard.
- `hotspot-frequency` fast conifg to change frequency
- `hotspot-options` fast config to set options like thermal optimalization and background announcement of the remote call (repeater/hotspot user)
- `hotspot-talkgroups` fast config to change/add default talkgroup and talkgroup to ctcss mapping
- `hotspot-volume` fast config option to set volume

---
