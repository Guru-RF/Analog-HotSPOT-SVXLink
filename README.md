# SVXSpot: An SVXLink Analog Hotspot/Transceiver for the Raspberry Pi Zero

# Quick Start

1. Flash the image to an SD card (https://etcher.balena.io/#download-etcher):  (The device already includes a freshly flashed SD card — you can skip this step and go straight to step 2.)

   https://storage.googleapis.com/rf-guru/rpi-images/hotspot-2025-12-09.img.gz

3. Insert the SD card into the **Raspberry Pi Zero 2W** and power it with a **stable 5V supply** (usb port on the far right of the device).

4. Wait for it to boot up.
   While waiting for boot you can subscribe to our RF Guru's Analog Hotspot mailinglist. https://listmonk.rf.guru/subscription/form

6. Connect to the Wi-Fi AccessPoint of the Hotspot SSID:  
   **AccessPopup**  
   Password: **1234567890**

7. Open the dashboard:  
   http://192.168.50.5/ (or http://hotspot.local)

8. Open **Shell** → log in:  
   - Username: `hotspot`  
   - Password: `hotspot`

   ![screenshot](https://github.com/user-attachments/assets/27ffa551-375e-4ca4-b025-78ead10c1f55)


9. Configure Wi-Fi (add as many networks you want, but **do not remove AccessPopup**):

        sudo nmtui

   (YouTube how-to) https://youtu.be/EJn0JkStWuY

   **Note:** When you **save** a new Wi-Fi network, the hotspot may **immediately connect to it** and disable the **AccessPopup** access point. Your PC will then **lose the AccessPopup Wi-Fi** connection (this is normal). Just connect your PC to **your own Wi-Fi network**, then reopen the portal via: http://hotspot.local (or use the announced IP address if mDNS is not available) login hotspot/hotspot and go to step 12.

11. Reboot:

        sudo reboot

12. After reboot, connect via:  
   - http://hotspot.local  
   **or**  
   - the **spoken IP address** announced over RF (434.925 MHz — FM Narrow | 145.925 MHz — FM Narrow)
   - If this does not work, check whether the AccessPopup network is still being broadcast over Wi-Fi. If it is, something went wrong while entering your network details. Go back to point 6 and repeat the setup.

13. Start configuration:

Use your own email adress ! And use real coordinates, some reflectors do not like hotspots info to be hidden ! Look at the local AUP!

```bash
sudo hotspot-config
```

(video demo https://youtu.be/bKF9JRo0ORM?t=125)

14. For Belgian users, set the domain:

    *be.svx.link* is the domain, the portal of this domain is https://portal.be.svx.link

15. After initial configuration, your **SVXReflector sysop must sign your certificate**.  
    Once signed, your hotspot is fully operational.

16. Continue setup:

We encourage everyone to leave Temperature tuning on !

Some people find the callsigns announcements in QSO's ennoying, you can turn this on or off here!

```bash
sudo hotspot-options
```

17. Belgian users can update talkgroups + button presets:

```bash
sudo hotspot-on-webportal
```

18. You are now **ready to rumble** 🎙️📡

---

## 4G/LTE Setup

Best to install these first — once 4G is up, `wlan0` is brought down and
you'll need an alternate way in if anything misbehaves:

- [Raspberry Pi Connect](https://github.com/Guru-RF/Analog-HotSPOT-SVXLink#raspberry-pi-connect) — remote shell over the internet
- [Installing Bluetooth for the HotSpot companion app](https://github.com/Guru-RF/Analog-HotSPOT-SVXLink#installing-bluetooth-for-the-hotspot-companion-app) — BLE fallback to toggle 4G off if it gets stuck

For the 4G version install the module via:
(it's default configured for the https://alwaysconnected.eu/ provider)

```bash
sudo install-4gmodule
```

Configure another provider

```bash
sudo hotspot-4g-config
```

---

## Available Products
- **RF.Guru Analog Hotspot/Transceiver**  
  https://shop.rf.guru/collections/hotspot  
  300–500 mW Output Power

---

# SVXLink Bookworm Image

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

# Mailinglist for software updates

https://listmonk.rf.guru/subscription/form

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

# Supported PI's

- Raspberry PI4
- Raspberry PI5
- Raspberry PiZero 2W
- Raspberry Compute Module 4
- Raspberry Compute Module 5

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

    DTMF 91<TALKGROUP>#

---

# Retrieving the Current IP Address

To get the current IP address of the hotspot, send:

    DTMF D911#

---

# Monitoring Multiple Talkgroups

To set up multiple talkgroups for monitoring, configure them in hotspot-config using this format:

    8++, 23+, 50, 51, 52, 53, 54, 55

The TX CTCSS tone remains the same across all talkgroups.
The plus signs (+) indicate priority levels. More plus signs mean higher priority. While a talk group is selected, and there is activity on a talk group with higher priority, the higher prio talk group will be selected.


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

To switch wait until hotspot is on talkgroup 0 or send DTMF 910#
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

Use a tone/frequency not locally used.

For the CTCSS TX tone best to pick on between 67 and 85.4 (best audio quality)

---

# Installing Bluetooth for the HotSpot companion app

Enables a BLE GATT service so a phone or laptop can drive the hotspot
(send DTMF, restart SVXLink, toggle 4G, watch live state) without SSH.

Install on the hotspot:

```bash
    sudo /usr/sbin/install-bluetooth
```

After install, the device advertises over BLE as its hostname.

## On the client (Windows / macOS / Linux / iOS / Android)

- **Turn Bluetooth on** in the OS — that's all the OS-level setup needed.
- **Do not pair the hotspot** in the system Bluetooth settings. You won't
  see it there anyway, and pairing isn't required.

This is **Bluetooth Low Energy (BLE)**, not classic Bluetooth. BLE works
differently from headphones / keyboards / car kits:

- Devices expose **GATT services** identified by UUID. The companion app
  scans for the hotspot's service UUID directly and connects to it; the
  device never shows up in the OS "Bluetooth devices" list.
- **No pairing / PIN.** The link is unencrypted and the hotspot accepts
  any client in radio range that knows the service UUID. (This is fine
  for a desk hotspot; if yours is mobile / public, see `BLE.md` for the
  bonded-mode flag.)
- The OS radio just needs to be **powered on** so the app can use it.

## Belgian users — SvxPortalApp

If you're on the Belgian reflector, use **SvxPortalApp**:

https://github.com/Guru-RF/SvxPortalApp/releases

Currently available for **macOS / Windows / Linux**; iOS and Android will
follow.

For everybody else: the portal app integrates deeply with the reflector
and needs extra software running on the reflector side. If there's
interest in deploying it on your own reflector, please get in touch.

## Standalone companion app — everyone

There is also a standalone companion app that talks to any hotspot over
BLE without any reflector-side dependency:

https://github.com/Guru-RF/Analog-HotSPOT-App/releases

Available for **macOS / Windows / Linux**; iOS and Android will follow.
It has no map and you need to define the talkgroups manually.

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

# Backup the certificate

> **Note:** the reflector certificate is only valid for **90 days** and
> SVXLink **renews it automatically** as long as the hotspot is online
> and registered on the reflector. You normally don't need to back it up.
> This is mostly convenient when **flashing a fresh SD card** so you can
> skip the sysop-signing wait on the new install.

The reflector cert/key live under `/var/lib/svxlink/pki/`. Once your sysop
has signed it, back it up so you don't have to wait for re-signing if you
re-flash the SD card.

The hotspot already runs a local webserver at <http://hotspot.local> with
its document root at `/var/www/html/` — drop the tarball there and pull
it from your laptop.

```bash
    sudo tar czf /var/www/html/svxlink-pki-$(hostname)-$(date +%Y%m%d).tgz -C /var/lib/svxlink pki
```

Download from the browser:

    http://hotspot.local/svxlink-pki-<hostname>-<date>.tgz

**Then immediately remove it from the web root** — the private key is
inside, and anyone on the same network can grab it while it sits there:

```bash
    sudo rm -f /var/www/html/svxlink-pki-*.tgz
```

To restore on a fresh install (after running `hotspot-config` once so the
directory exists), copy the tarball back with `scp` using the default
`hotspot` / `hotspot` login.

From your laptop:

```bash
    scp svxlink-pki-<hostname>-<date>.tgz hotspot@hotspot.local:/tmp/
```

**On Windows:** modern Windows 10/11 ships `scp` via OpenSSH so the
command above works as-is in PowerShell. If you prefer a GUI, use
[WinSCP](https://winscp.net/) — connect to `hotspot.local` on port 22
with username `hotspot` / password `hotspot`, then drag the `.tgz` file
into `/tmp/` on the right-hand pane.

Then on the hotspot:

```bash
    sudo tar xzf /tmp/svxlink-pki-*.tgz -C /var/lib/svxlink
    sudo chown -R svxlink:svxlink /var/lib/svxlink/pki
    sudo rm -f /tmp/svxlink-pki-*.tgz
    sudo systemctl restart svxlink
```

---

# Remove certificates (and request a new one)

```bash
    sudo rm -f /var/lib/svxlink/pki/*
    sudo systemctl restart svxlink
```

---

# Raspberry Pi Connect

Connect remotely to your hotspot.

https://connect.raspberrypi.com

Install rpi-connect

```bash
    sudo apt -y install rpi-connect-lite
    loginctl enable-linger
    rpi-connect on
    rpi-connect signin
```

---

# 2nd USB port

The second USB port can be used for ethernet, or to attach an AMBE dongle for Bridging to DMR !

---

# Repeater Mode

Extras useful when you're running the box as an actual repeater rather than a personal hotspot.

## svxlink-watchdog

Watches **GPIO16 (PTT)** once per second. If the PTT line stays asserted (LOW) for more than **150 seconds**, it assumes SVXLink is stuck in a keyed state and runs `systemctl restart svxlink`. While the pin is LOW, the script logs a countdown every 5 seconds.

Follow it live with:

```bash
sudo journalctl -t svxlink-watchdog -f
```

Install (no clone, no `hotspot-config` needed):

```bash
wget -qO- https://raw.githubusercontent.com/Guru-RF/Analog-HotSPOT-SVXLink/master/install-svxlink-watchdog.sh | sudo bash
```

The installer pulls the script + systemd unit, enables `svxlink-watchdog.service`, and starts it.

---

# SVXLink Hotspot in Action

https://github.com/Guru-RF/SVXSpot/assets/1251767/50dd4366-8439-4067-83b5-5866d0adca77
