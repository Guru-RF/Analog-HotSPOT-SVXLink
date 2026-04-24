#!/bin/bash

run() {
  exec=$1
  printf "\x1b[38;5;104m --> ${exec}\x1b[39m\n"
  eval ${exec}
}

say () {
  say=$1
  printf "\x1b[38;5;220m${say}\x1b[38;5;255m\n"
}

RAW="https://raw.githubusercontent.com/Guru-RF/Analog-HotSPOT-SVXLink/master"

say "Downloading svxlink-watchdog"
run "wget -O /usr/sbin/svxlink-watchdog $RAW/svxlink-watchdog.sh"
run "chmod +x /usr/sbin/svxlink-watchdog"

say "Downloading svxlink-watchdog.service"
run "wget -O /etc/systemd/system/svxlink-watchdog.service $RAW/svxlink-watchdog.service"

say "Enable and start svxlink-watchdog"
run "systemctl daemon-reload"
run "systemctl enable svxlink-watchdog"
run "systemctl restart svxlink-watchdog"

say "Done."
