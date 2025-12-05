# SVXSpot: An SVXLink Analog Hotspot/Transceiver for the Raspberry Pi Zero

# Quick Start

1. Flash the image to an SD card:  
   https://storage.googleapis.com/rf-guru/rpi-images/hotspot-2025-12-05.img.gz

2. Insert the SD card into the **Raspberry Pi Zero 2W** and power it using a **stable 5V supply**.

3. Wait **10 minutes** on the very first boot (filesystem resize bug workaround), then power-cycle the Pi.

4. Connect to Wi-Fi SSID:  
   - **AccessPopup**  
   - Password: **1234567890**

5. Open the dashboard at:  
   http://192.168.50.5/

6. Open **Shell** → log in:  
   - Username: `hotspot`  
   - Password: `hotspot`

7. Configure your own Wi-Fi:

       sudo nmtui

8. Reboot:

       sudo reboot

9. After reboot, log in via:  
   - http://hotspot.local  
   **or**  
   - the **spoken IP address** announced over RF

10. Start the configuration wizard:

       sudo hotspot-config

11. For Belgian users, set the SVXLink domain to:  
       be.svx.link

12. After completing the wizard:  
    Your **repeater sysadmin must sign your certificate request**.

13. Once signed, continue setup:

       sudo hotspot-options

14. Belgian users can update talkgroups + button presets:

       sudo hotspot-on-webportal

15. You are now **ready to rumble** 🎙️📡

---

## Available Products
- **RF.Guru Analog Hotspot/Transceiver**  
  https://shop.rf.guru/collections/hotspot  
  300–500 mW Power Output

---

## Repository Overview

This repository contains the release branch of **SVXSpot**, the software used on RF.Guru analog hotspots.

After initial configuration, your **SVXReflector sysop** must sign your certificate.  
Once signed, your hotspot is fully operational.

---

# SVXLink Bookworm Image (2025-12-05)

Supports **UHF** and **VHF** operation on Raspberry Pi Zero 2W.

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

The Pi Zero 2W is sensitive to voltage drops — use a **high-quality 5V supply**.

A known `pi-shrink` bug may cause the Pi to freeze after filesystem expansion.

**Workaround:**  
1. Boot and wait **10 minutes**  
2. Remove power  
3. Power on again

---

# Wi-Fi Setup (AccessPopup)

1. Connect to:
   - **SSID:** AccessPopup  
   - **Password:** 1234567890

2. Open:
   http://192.168.50.5/

3. Choose **Shell** to enter the terminal.

### Login Credentials
- Username: `hotspot`  
- Password: `hotspot`

(Change later using `passwd`.)

### Configure Wi-Fi

    sudo nmtui

Select your network → save → exit → reboot:

    sudo reboot

### After reboot

If your router supports mDNS:

http://hotspot.local/

If your network does **not** support mDNS:  
The hotspot will **announce its IP address over RF** on the default frequency (spoken IP).  
This makes it accessible even on simple networks.

Video guide:  
https://www.youtube.com/watch?v=bKF9JRo0ORM

---

# Additional Built-In Features

### Fast Commands
- `D911#` — Speaks the hotspot’s IP address over RF  
- `hotspot-frequency` — Quick frequency setup  
- `hotspot-options` — Thermal + announcement settings  
- `hotspot-talkgroups` — Talkgroup + CTCSS mapping  
- `hotspot-volume` — Audio level adjustment

---

# Hardware Information (GPIO)

GPIO pins used by the SVXSpot HAT:

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

iOS does **not broadcast the hotspot SSID continuously**.  
Open **Settings → Personal Hotspot** to force the SSID to appear.

Once connected, it works normally.

---

# Logs

Live log monitoring:

    sudo tail -f /var/log/svxlink

---

# SVXLink Hotspot in Action

https://github.com/Guru-RF/SVXSpot/assets/1251767/50dd4366-8439-4067-83b5-5866d0adca77
