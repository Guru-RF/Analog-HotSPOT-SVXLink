# SVXSpot: An SVXLink Analog Hotspot/Transceiver for the Raspberry Pi Zero

# Quick Start

1. Flash the image to an SD card:  (The device already includes a freshly flashed SD card — you can skip this step and go straight to step 3.)

   https://storage.googleapis.com/rf-guru/rpi-images/hotspot-2025-12-09.img.gz

3. Insert the SD card into the **Raspberry Pi Zero 2W** and power it with a **stable 5V supply**.

4. Wait for it to boot up.

5. Connect to the Wi-Fi SSID:  
   **AccessPopup**  
   Password: **1234567890**

6. Open the dashboard:  
   http://192.168.50.5/ (or http://hotspot.local)

7. Open **Shell** → log in:  
   - Username: `hotspot`  
   - Password: `hotspot`

8. Configure Wi-Fi:

        sudo nmtui

9. Reboot:

        sudo reboot

10. After reboot, connect via:  
   - http://hotspot.local  
   **or**  
   - the **spoken IP address** announced over RF (434.925 MHz — FM Narrow | 145.925 MHz — FM Narrow)

11. Start configuration:

```bash
sudo hotspot-config
```

11. For Belgian users, set the domain:

    be.svx.link

12. After initial configuration, your **SVXReflector sysop must sign your certificate**.  
    Once signed, your hotspot is fully operational.

13. Continue setup:

```bash
sudo hotspot-options
```

14. Belgian users can update talkgroups + button presets:

```bash
sudo hotspot-on-webportal
```

15. You are now **ready to rumble** 🎙️📡

---

## Available Products
- **RF.Guru Analog Hotspot/Transceiver**  
  https://shop.rf.guru/collections/hotspot  
  300–500 mW Output Power

---

# SVXLink Bookworm Image (2025-12-05)

Supports **UHF** and **VHF** on Raspberry Pi Zero 2W.

## Default Configuration

### UHF
- **434.925 MHz** — FM Narrow  
- CTCSS Input: **88.5 Hz**  
- CTCSS Output: **250.3 Hz**

### VHF
- **145.925 MHz** — FM Narrow  
- CTCSS Input: **88.5 Hz**  
- CTCSS Output: **250.3 Hz**

### Download  
https://storage.googleapis.com/rf-guru/rpi-images/hotspot-2025-12-09.img.gz

---

# Wi-Fi Setup (AccessPopup)

1. Connect to:
   - **SSID:** AccessPopup  
   - **Password:** 1234567890

2. Open:  
   http://192.168.50.5/

3. Choose **Shell**.

### Login
- Username: `hotspot`  
- Password: `hotspot`

### Configure Wi-Fi

        sudo nmtui

Reboot:

        sudo reboot

### After reboot

If your router supports mDNS:

http://hotspot.local/

If not:  
The hotspot **announces its IP address over RF** on the default frequency. (434.925 MHz — FM Narrow | 145.925 MHz — FM Narrow)

Tutorial video:  
https://www.youtube.com/watch?v=bKF9JRo0ORM

---

# Built-In Tools

- `D911#` — Speaks IP address over RF  
- `hotspot-frequency` — Quick frequency setup  
- `hotspot-options` — Thermal + announcements  
- `hotspot-talkgroups` — Talkgroup/CTCSS mapping  
- `hotspot-volume` — Audio control

---

# GPIO Pin Usage

- Pin 3  → GPIO2  
- Pin 6  → GPIO3  
- Pin 35 → GPIO19  
- Pin 8  → TX  
- Pin 10 → RX  
- Pin 12 → CLK  
- Pin 32 → GPIO12 (**COS input**)  
- Pin 36 → GPIO16 (**PTT**)  
- Pin 38 → GPIO20  
- Pin 40 → GPIO21  
- Pin 31 → GPIO6  
- Pin 33 → GPIO13  
- Pin 25 → GPIO7  
- Pin 29 → GPIO5  

---

# iPhone Hotspot Notes

iOS does **not** broadcast the hotspot SSID continuously.  
Open **Settings → Personal Hotspot** to force visibility.

---

# Logs

```bash
sudo tail -f /var/log/svxlink
```

---

# Activating a Talkgroup

To activate a talkgroup, send the corresponding CTCSS tone from the mapping while in TG0.

You’ll hear a bleep tone 15 seconds after a QSO.
This will instantly open the talkgroup – no need for double presses like before.
You can start speaking immediately!

Alternatively you can use:

    DTMF 91#

---

# Retrieving the Current IP Address

To get the current IP address of the hotspot, send:

    DTMF D911#

---

# Monitoring Multiple Talkgroups

To set up multiple talkgroups for monitoring, configure them in hotspot-config using this format:

    8++, 23+, 50, 51, 52, 53, 54, 55

The TX CTCSS tone remains the same across all talkgroups.
The plus signs (+) indicate priority levels.

Temporarily monitor (for one hour) another talkgroup:

    DTMF 94#

Example for TG23:

    9423#

---

# CTCSS Talkgroup Mapping

You can map talkgroups via CTCSS tones using the following format:

    tone:talkgroup, tone:talkgroup, …

Example default mapping:

    67.0:8400, 69.3:8, 71.9:23, 74.4:9000, 77.0:50, 79.7:51, 82.5:52, 85.4:53, 88.5:54, 91.5:55

Mapping a single default talkgroup:

    88.5:8

This maps CTCSS tone 88.5 to talkgroup 8.

---

# Accessing the Local Portal

You can access the local dashboard:

- Via hostname (if your network supports mDNS)
- Or via the hotspot’s IP address

---

# Choosing a Frequency and CTCSS Tone

We advise selecting a frequency not used by nearby repeaters.
Do **not** use the ISM frequency 433.000 MHz.

Recommended defaults we use:

- **70 cm:** 439.100 MHz  
- **2 m:** 145.250 MHz  
- **CTCSS:** 88.5 Hz

Use a tone not locally used.

---

# Modify Talkgroups on the Dashboard

Edit base talkgroups:

```bash
    sudo vi /var/www/html/include/tgdb.php
```

Edit talkgroup buttons:

```bash
    sudo vi /var/www/html/include/config.inc.php
```

---

# SVXLink Hotspot in Action

https://github.com/Guru-RF/SVXSpot/assets/1251767/50dd4366-8439-4067-83b5-5866d0adca77
