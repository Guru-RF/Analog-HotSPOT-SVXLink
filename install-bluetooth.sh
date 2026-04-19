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

say "Installing Bluetooth prerequisites"
run "apt install -y bluez python3-dbus python3-gi"

REBOOT_NEEDED=0
say "Ensuring onboard Bluetooth is enabled (removing dtoverlay=disable-bt)"
for cfg in /boot/firmware/config.txt /boot/config.txt; do
  if [[ -f "$cfg" ]] && grep -qE '^[[:space:]]*dtoverlay=disable-bt[[:space:]]*$' "$cfg"; then
    run "sed -i -E '/^[[:space:]]*dtoverlay=disable-bt[[:space:]]*\$/d' $cfg"
    REBOOT_NEEDED=1
  fi
done

say "Install hotspot-bluetooth"
run "cp hotspot-bluetooth /usr/sbin/hotspot-bluetooth"
run "chmod +x /usr/sbin/hotspot-bluetooth"

say "Install hotspot-bluetooth.service"
run "cp hotspot-bluetooth.service /lib/systemd/system/hotspot-bluetooth.service"
run "systemctl daemon-reload"
run "systemctl enable hotspot-bluetooth"
run "systemctl restart hotspot-bluetooth"

say "Done. Advertising as $(hostname)"
[[ "$REBOOT_NEEDED" = "1" ]] && say "Reboot required: dtoverlay=disable-bt was removed from config.txt"
