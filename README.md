# SVXSpot: An SVXLink Analog Hotspot/Transcevier for the Raspberry Pi Zero

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

Boot the hotspot with a descent power supply that can provide enough current and has a stable voltage > 5v !

It appears that the Raspberry Pi freezes after resizing the file system. Currently, after the initial boot, wait for 10 minutes, disconnect the power, and then restart. We suspect this issue is a bug and anticipate it will likely be resolved in a future release of pi-shrink.

To complete the final configuration step, you can connect via WiFi to the build-in AccessPopup called AccessPoppup with passkey 1234567890, go to the dashboard by browsing to [http://192.168.50.5/](http://192.168.50.5/). Chooce shell for shell access !

Username: hotspot
Pasword: hotspot (you can change it when logged in by entering passswd)

Once logged in, you can execute:
```console
sudo nmtui
```
Add your WiFi Network, quit, and reboot by:
```console
sudo reboot
```

Once rebooted you can configure your hotspot by browsing to [http://hotspot.local/](http://hotspot.local/)

This Youtube video illustrates the whole procuedure: [YouTube](https://www.youtube.com/watch?v=bKF9JRo0ORM)

### Additional Features:
- Sending `D911#` will return the **IP address**, making it easy to access the dashboard.
- `hotspot-frequency` fast conifg to change frequency
- `hotspot-options` fast config to set options like thermal optimalization and background announcement of the remote call (repeater/hotspot user)
- `hotspot-talkgroups` fast config to change/add default talkgroup and talkgroup to ctcss mapping
- `hotspot-volume` fast config option to set volume

---

## Hardware Info

**Used PIN's:**
 - 3 **GPIO2** 
 - 6 **GPIO3** 
 - 35 **GPIO19** 
 - 8 **TX** 
 - 10 **RX**
 - 12 **CLK** 
 - 32 **GPIO12** -> ***COS input*** from the radio chip 
 - 36 **GPIO16** -> ***PTT*** pin 
 - 38 **GPIO20** 
 - 40 **GPIO2**
 - 31 **GPIO6**
 - 33 **GPIO13**
 - 25 **GPIO7**
 - 29 **GPIO5**

 # iPhone Personal Hotspot

You need to go to Personal Hotspot setting until the hotspot is connected, there is no option on the iPhone/iPad to have the SSID beeing broadcasted all the time.
Once connected it works like a charm.

# Logs
```console
sudo tail -f /var/log/svxlink
```

### SVXLink Hotspot in action ###
https://github.com/Guru-RF/SVXSpot/assets/1251767/50dd4366-8439-4067-83b5-5866d0adca77
