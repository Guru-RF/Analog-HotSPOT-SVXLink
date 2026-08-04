#!/bin/bash

# curl -fsSL https://raw.githubusercontent.com/Guru-RF/Analog-HotSPOT-SVXLink/refs/heads/main/test.sh | sudo bash

systemctl stop svxlink
sa818 --port /dev/serial0 radio --bw 0 --frequency 434.925 --ctcss 250.3,0 --squelch 8
sa818 --port /dev/serial0 filters --emphasis enable --highpass enable --lowpass enable
sa818 --port /dev/serial0 volume --level 1

# Apply the audio-mixer setup. Codec-aware (WM8960 vs TLV320AIC3204)
# via hotspot-audio-detect — same defaults hotspot-config lays down.
/usr/sbin/hotspot_volume

gpioset gpiochip0 16=1
cd /tmp
rm -f ImperialMarch60.wav
wget https://github.com/Guru-RF/Analog-HotSPOT-SVXLink/raw/refs/heads/main/ImperialMarch60.wav
gpioset gpiochip0 16=0
sleep 10
aplay ImperialMarch60.wav
gpioset gpiochip0 16=1
