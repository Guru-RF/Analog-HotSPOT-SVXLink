# SVXSpot: An SVXLink Analog Hotspot/Transceiver for the Raspberry Pi Zero

## Available Products
- **RF.Guru Analog Hotspot/Transceiver**  
  https://shop.rf.guru/collections/hotspot  
  300–500 mW Power Output

---

## Repository Overview

This repository contains the release branch of **SVXSpot**, the software stack used on RF.Guru analog hotspots.

After completing the initial configuration, your **SVXReflector sysop** must sign your certificate.  
Once this is done, your hotspot is fully operational.

---

# SVXLink Bookworm Image (2025-12-05)

This image supports both **UHF** and **VHF** operation on the **Raspberry Pi Zero 2W**.

## Default Configuration

### UHF
- Frequency: **434.925 MHz**
- Mode: FM Narrow  
- Input CTCSS: **88.5 Hz**  
- Output CTCSS: **250.3 Hz**

### VHF
- Frequency: **145.925 MHz**
- Mode: FM Narrow  
- Input CTCSS: **88.5 Hz**  
- Output CTCSS: **250.3 Hz**

### Download
Bookworm Image (2025-12-05):  
https://storage.googleapis.com/rf-guru/rpi-images/hotspot-2025-12-05.img.gz

---

## First Boot Instructions

Use a **stable 5V power supply** (the Pi Zero 2W is sensitive to voltage drops).

After the first boot, the Pi resizes the filesystem.  
There is currently an upstream `pi-shrink` bug causing the Pi to freeze after resizing.

**Temporary workaround:**
1. Boot and wait **10 minutes**.  
2. Disconnect power.  
3. Power it back on.

---

# Wi-Fi Setup (AccessPopup)

1. The hotspot broadcasts a Wi-Fi network:  
   **SSID:** AccessPopup  
   **Password:** 1234567890

2. Connect and browse to:  
   http://192.168.50.5/

3. Select **Shell** to open a terminal.

### Login
- Username: hotspot  
- Password: hotspot

(Change this using `passwd` after login.)

### Configure your Wi-Fi

\`\`\`console
sudo nmtui
\`\`\`

Select your network, save, exit, then reboot:

\`\`\`console
sudo reboot
\`\`\`

### After reboot

If your network/router supports mDNS, open:  
http://hotspot.local/

Video guide:  
https://www.youtube.com/watch?v=bKF9JRo0ORM

---

# Additional Built-In Features

### Fast Commands
- `D911#` — Returns the hotspot's IP address via RF  
- `hotspot-frequency` — Quick frequency setup  
- `hotspot-options` — Thermal settings + callsign announcement control  
- `hotspot-talkgroups` — Talkgroup and CTCSS mapping  
- `hotspot-volume` — Adjust audio levels

---

# Hardware Information (GPIO)

These Raspberry Pi GPIO pins are used by SVXSpot:

- Pin 3: GPIO2  
- Pin 6: GPIO3  
- Pin 35: GPIO19  
- Pin 8: TX  
- Pin 10: RX  
- Pin 12: CLK  
- Pin 32: GPIO12 — COS input  
- Pin 36: GPIO16 — PTT  
- Pin 38: GPIO20  
- Pin 40: GPIO21  
- Pin 31: GPIO6  
- Pin 33: GPIO13  
- Pin 25: GPIO7  
- Pin 29: GPIO5  

---

# iPhone Personal Hotspot Notes

On iOS, the Personal Hotspot SSID is **not broadcast continuously**.  
Open the **Personal Hotspot** settings page for the Pi to detect it.

Once connected, it works reliably.

---

# Logs

Monitor live SVXLink logs:

\`\`\`console
sudo tail -f /var/log/svxlink
\`\`\`

---

# SVXLink Hotspot in Action

https://github.com/Guru-RF/SVXSpot/assets/1251767/50dd4366-8439-4067-83b5-5866d0adca77
