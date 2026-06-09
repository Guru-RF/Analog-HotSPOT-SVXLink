#!/bin/bash

# curl -fsSL https://raw.githubusercontent.com/Guru-RF/Analog-HotSPOT-SVXLink/refs/heads/main/test.sh | sudo bash

systemctl stop svxlink
sa818 --port /dev/serial0 radio --bw 0 --frequency 434.925 --ctcss 250.3,0 --squelch 8
sa818 --port /dev/serial0 filters --emphasis enable --highpass enable --lowpass enable
sa818 --port /dev/serial0 volume --level 1
# audio to radio Module
amixer set 'Headphone' 75%
# audio from radio Module
amixer set 'Capture' 17%


# Disable ALC en Deemphasis
amixer cset iface=MIXER,name='DAC Deemphasis Switch' 0
amixer cset iface=MIXER,name='ALC Function' 0
amixer cset iface=MIXER,name='ALC Target' 0
amixer cset iface=MIXER,name='ALC Mode' 1
amixer cset iface=MIXER,name='ALC Attack' 0
amixer cset iface=MIXER,name='ALC Decay' 0
amixer cset iface=MIXER,name='ALC Hold Time' 0
amixer cset iface=MIXER,name='ALC Max Gain' 0
amixer cset iface=MIXER,name='ALC Min Gain' 0
amixer cset iface=MIXER,name='ADC High Pass Filter Switch' 0
gpioset gpiochip0 16=1
cd /tmp
rm -f ImperialMarch60.wav
wget https://github.com/Guru-RF/Analog-HotSPOT-SVXLink/raw/refs/heads/main/ImperialMarch60.wav
gpioset gpiochip0 16=0
sleep 10
aplay ImperialMarch60.wav
gpioset gpiochip0 16=1

