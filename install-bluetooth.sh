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

say "Installing Bluetooth prerequisites"
run "apt install -y bluez python3-dbus python3-gi wget"

REBOOT_NEEDED=0
say "Ensuring onboard Bluetooth is enabled (removing dtoverlay=disable-bt)"
for cfg in /boot/firmware/config.txt /boot/config.txt; do
  if [[ -f "$cfg" ]] && grep -qE '^[[:space:]]*dtoverlay=disable-bt[[:space:]]*$' "$cfg"; then
    run "sed -i -E '/^[[:space:]]*dtoverlay=disable-bt[[:space:]]*\$/d' $cfg"
    REBOOT_NEEDED=1
  fi
done

say "Tuning /etc/bluetooth/main.conf for stable BLE on the combo chip"
if [[ -f /etc/bluetooth/main.conf ]]; then
  run "cp -n /etc/bluetooth/main.conf /etc/bluetooth/main.conf.orig || true"
  # LE-only avoids BR/EDR contention on the BCM43438 combo radio.
  run "sed -i -E 's/^[#[:space:]]*(ControllerMode[[:space:]]*=).*/\1 le/' /etc/bluetooth/main.conf"
  run "sed -i -E 's/^[#[:space:]]*(Experimental[[:space:]]*=).*/\1 true/' /etc/bluetooth/main.conf"
  # FastConnectable is a BR/EDR page-scan tweak the BCM43438 firmware
  # rejects ("Failed to set mode: Not Supported"). Force it off.
  run "sed -i -E 's/^[#[:space:]]*(FastConnectable[[:space:]]*=).*/\1 false/' /etc/bluetooth/main.conf"
  # LE advertisement interval (ms). Lower = quicker reconnect after a drop.
  run "sed -i -E 's/^[#[:space:]]*(MinAdvertisementInterval[[:space:]]*=).*/\1 100/' /etc/bluetooth/main.conf"
  run "sed -i -E 's/^[#[:space:]]*(MaxAdvertisementInterval[[:space:]]*=).*/\1 150/' /etc/bluetooth/main.conf"
fi

say "Enabling bluetoothd --experimental (needed for several BLE stability fixes)"
BTD=$(awk -F= '/^ExecStart=/{ print $2; exit }' /lib/systemd/system/bluetooth.service 2>/dev/null | awk '{print $1}')
[[ -z "$BTD" ]] && BTD=/usr/libexec/bluetooth/bluetoothd
run "mkdir -p /etc/systemd/system/bluetooth.service.d"
# We only speak GATT over LE. Disable every plugin that targets classic
# audio / telephony / HID — they spam the log with SDP-registration errors
# (AVRCP "Operation not permitted" etc.) when BR/EDR is off, and the MIDI
# plugin in particular is a documented cause of GATT disconnects on Pi.
NOPLUGIN=midi,sap,input,hog,a2dp,avrcp,audio,hsp,hfp,pbap,map,obex,network,health,wiimote
cat > /etc/systemd/system/bluetooth.service.d/experimental.conf <<EOF
[Service]
ExecStart=
ExecStart=$BTD --experimental --noplugin=$NOPLUGIN
EOF
run "systemctl daemon-reload"
run "systemctl restart bluetooth"

say "Downloading hotspot-bluetooth"
run "wget -O /usr/sbin/hotspot-bluetooth $RAW/hotspot-bluetooth"
run "chmod +x /usr/sbin/hotspot-bluetooth"

say "Downloading hotspot-bluetooth.service"
run "wget -O /etc/systemd/system/hotspot-bluetooth.service $RAW/hotspot-bluetooth.service"

say "Enable and start hotspot-bluetooth"
run "systemctl daemon-reload"
run "systemctl enable hotspot-bluetooth"
run "systemctl restart hotspot-bluetooth"

say "Done. Advertising as $(hostname)"
[[ "$REBOOT_NEEDED" = "1" ]] && say "Reboot required: dtoverlay=disable-bt was removed from config.txt"
