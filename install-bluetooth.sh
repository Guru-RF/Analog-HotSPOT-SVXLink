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
INSTALLER_NAME="sudo /usr/sbin/install-bluetooth"

# Refuse to install on a not-fully-updated OR not-yet-rebooted OS — a
# kernel/libc upgrade left half-applied would put userspace and modules
# out of sync, and the BlueZ stack in particular often needs the
# post-upgrade reboot to enumerate the controller cleanly.
ensure_os_ready() {
  say "Checking for pending OS updates"
  if ! apt-get update -qq 2>/dev/null; then
    say "WARNING: apt update failed (offline?) — checking against the cached package list"
  fi

  PENDING=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst ')
  if [[ "${PENDING}" -gt 0 ]]; then
    say ""
    say "STOP — there are ${PENDING} pending package upgrade(s)."
    say "Please run, in order:"
    say ""
    say "    sudo apt -y update && sudo apt -y upgrade"
    say "    sudo reboot"
    say ""
    say "and then re-run:  ${INSTALLER_NAME}"
    say ""
    say "First 10 pending packages:"
    apt-get -s upgrade 2>/dev/null | grep '^Inst ' | head -10 | sed 's/^Inst /  - /'
    if [[ "${PENDING}" -gt 10 ]]; then
      say "  ... and $((PENDING - 10)) more"
    fi
    exit 1
  fi

  if [[ -f /var/run/reboot-required ]]; then
    say ""
    say "STOP — the system applied updates that require a reboot first."
    say "(/var/run/reboot-required is present)"
    say ""
    say "Please run:"
    say ""
    say "    sudo reboot"
    say ""
    say "and then re-run:  ${INSTALLER_NAME}"
    exit 1
  fi

  RUNNING_KERNEL=$(uname -r)
  LATEST_KERNEL=$(dpkg-query -W -f='${Package}\n' 'linux-image-*' 2>/dev/null \
                  | grep -E '^linux-image-[0-9]' \
                  | sed 's/^linux-image-//' \
                  | sort -V | tail -n1)
  if [[ -n "${LATEST_KERNEL}" && "${LATEST_KERNEL}" != "${RUNNING_KERNEL}" ]]; then
    say ""
    say "STOP — running kernel (${RUNNING_KERNEL}) is older than the installed kernel (${LATEST_KERNEL})."
    say "A reboot is needed before installing."
    say ""
    say "Please run:"
    say ""
    say "    sudo reboot"
    say ""
    say "and then re-run:  ${INSTALLER_NAME}"
    exit 1
  fi

  say "OS is up to date and current kernel is running"
}

ensure_os_ready

say "Installing Bluetooth prerequisites"
run "apt install -y bluez python3-dbus python3-gi wget rfkill"

say "Unblocking bluetooth (rfkill)"
run "rfkill unblock bluetooth"

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
