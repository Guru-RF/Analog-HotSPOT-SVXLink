# SVXSpot: An SVXLink Analog Hotspot/Transceiver for the Raspberry Pi Zero

## Available Products
- **RF.Guru Analog Hotspot/Transceiver**  
  https://shop.rf.guru/collections/hotspot  
  300–500 mW Power Output

---

## Repository Overview

This repository contains the release branch of **SVXSpot**, the software used on RF.Guru analog hotspots.

After completing the initial configuration, your **SVXReflector sysop** must sign your certificate.  
Once this is done, your hotspot is ready for use.

---

# SVXLink Bookworm Image (2025-12-05)

This image supports both **UHF** and **VHF** operation on the Raspberry Pi Zero 2W.

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
https://storage.googleapis.com/rf-guru/rpi-images/hotspot-2025-12-05.img.gz

---

## First Boot Instructions

Use a **stable 5V power supply**, as the Pi Zero 2W is sensitive to drops.

The first boot performs a filesystem resize.  
There is currently a `pi-shrink` bug causing freezes afterward.

**Temporary workaround:**  
1. Boot and wait **10 minutes**  
2. Remove power  
3. Power on again

---

# Wi-Fi Setup (AccessPopup)

1. The hotspot broadcasts this Wi-Fi network:  
   **SSID:** AccessPopup  
   **Password:** 1234567890

2. Connect and open:  
   http://192.168.50.5/

3. Select **Shell** for terminal access.

### Login
- Username: `hotspot`  
- Password: `hotspot`

(Change with `passwd` once logged in.)

### Configure Wi-Fi

    sudo nmtui

Select your network → save → exit  
Then reboot:

    sudo reboot

### After reboot
If your router supports mDNS, open:  
http://hotspot.local/

Video guide:  
https://www.youtube.com/watch?v=bKF9JRo0ORM

---

# Additional Built-In Features

### Fast Commands
- `D911#` — Returns the hotspot’s IP via RF  
- `hotspot-frequency` — Quick frequency setup  
- `hotspot-options` — Thermal + announcements  
- `hotspot-talkgroups` — Talkgroup + CTCSS mapping  
- `hotspot-volume` — Audio level adjustment

---

# Hardware Information (GPIO)

These Raspberry Pi GPIO pins are used:

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

On iOS, the Personal Hotspot SSID is not always broadcast.  
Open the **Personal Hotspot** settings screen to make it visible.

---

# Logs

Monitor SVXLink logs:

    sudo tail -f /var/log/svxlink

---

# SVXLink Hotspot in Action

https://github.com/Guru-RF/SVXSpot/assets/1251767/50dd4366-8439-4067-83b5-5866d0adca77
