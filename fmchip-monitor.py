#!/usr/bin/python3

import os
import subprocess

# Prefer /dev/serial0 — the kernel-maintained symlink to whichever UART is
# wired to GPIO 14/15 (PL011 when BT is disabled, mini-UART when BT is
# enabled). Falls back to legacy hardcoded paths for older images.
def _pick_port():
    for p in ("/dev/serial0", "/dev/ttyAMA0", "/dev/ttyS0"):
        if os.path.exists(p):
            return p
    return "/dev/serial0"

PORT = _pick_port()

f = subprocess.Popen(['tail','-n 0','-F','/var/log/svxlink'],\
        stdout=subprocess.PIPE,stderr=subprocess.PIPE)
while True:
    line = f.stdout.readline()
    if 'Turning the transmitter OFF' in str(line):
      print("Reset FM Chip")
      subprocess.run(["sa818","--port", PORT, "filters", "--emphasis", "disable", "--highpass", "disable", "--lowpass", "disable"])
