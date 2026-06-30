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

# Run a command in the background, show a spinner with a label on stderr
# until it finishes, then propagate its exit code. Stdout / stderr of
# the command go to /dev/null — wrap commands that need to capture output
# separately. Pure bash so it works before gum is installed.
spin_run() {
  local label=$1
  shift
  ( "$@" >/dev/null 2>&1 ) &
  local pid=$!
  local chars='-\|/'
  local i=0
  # \r returns to col-0; \x1b[2K clears the line so a shorter spinner
  # frame doesn't leave stale chars behind.
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r\x1b[2K\x1b[38;5;220m  %s %s\x1b[39m" "${chars:$((i % 4)):1}" "$label" >&2
    sleep 0.2
    i=$((i + 1))
  done
  wait "$pid"
  local rc=$?
  printf "\r\x1b[2K" >&2
  return $rc
}

RAW="https://raw.githubusercontent.com/Guru-RF/Analog-HotSPOT-SVXLink/master"
INSTALLER_NAME="sudo /usr/sbin/install-bluetooth"

# Refuse to install on a not-fully-updated OR not-yet-rebooted OS — a
# kernel/libc upgrade left half-applied would put userspace and modules
# out of sync, and the BlueZ stack in particular often needs the
# post-upgrade reboot to enumerate the controller cleanly.
# Consolidated prereq gate: check OS-update state AND BT-subsystem state in
# one pass, auto-fix what we can (disable-bt overlay, hciuart enable), and
# bail with ONE message listing everything the user needs to do — so they
# go through one apt-upgrade + one reboot cycle instead of bouncing through
# multiple stops.
ensure_ready_to_install() {
  say "Checking install prerequisites — this can take up to a minute on a fresh image or when unattended-upgrades is running in the background. Please wait..."

  # Accumulators. BLOCKERS are pre-existing issues the user must resolve;
  # AUTOFIXED are things we just changed that need a reboot to take effect.
  local -a BLOCKERS=()
  local -a AUTOFIXED=()
  local APT_UPGRADE_NEEDED=0
  local REBOOT_NEEDED=0

  # --- OS update freshness ---
  # apt-get update can stall when another apt process holds the lock
  # (unattended-upgrades is the common culprit) or a mirror is slow.
  # Cap at 30s and fall back to the cached package list rather than hang.
  if ! spin_run "Refreshing apt cache (up to 30s)" timeout 30 apt-get update -qq; then
    say "WARNING: apt update did not complete in 30s (offline, slow mirror, or another apt holds the lock — try 'sudo fuser /var/lib/dpkg/lock-frontend'). Continuing with the cached package list."
  fi

  # The cache-side simulation is the bit that's actually slow on a heavily
  # -pending box (100+ packages). Capture to tmpfile so we keep the head-10
  # listing for the report.
  local upgrade_out
  upgrade_out=$(mktemp)
  spin_run "Computing pending package list" bash -c "apt-get -s upgrade >'${upgrade_out}' 2>/dev/null"
  local PENDING
  PENDING=$(grep -c '^Inst ' "${upgrade_out}")
  if [[ "${PENDING}" -gt 0 ]]; then
    BLOCKERS+=("${PENDING} package upgrade(s) pending")
    APT_UPGRADE_NEEDED=1
    # Pending upgrades likely include a kernel — always pair the upgrade
    # with a reboot in the recovery instructions.
    REBOOT_NEEDED=1
  fi

  if [[ -f /var/run/reboot-required ]]; then
    BLOCKERS+=("/var/run/reboot-required present (system applied updates that need a reboot)")
    REBOOT_NEEDED=1
  fi

  local RUNNING_KERNEL LATEST_KERNEL
  RUNNING_KERNEL=$(uname -r)
  # Filter out the `-unsigned` flavour: Pi OS installs both the signed
  # (booted) and unsigned (not booted) kernel packages with the same
  # version, and `sort -V` would otherwise pick the unsigned name as
  # "newest" purely because "unsigned" sorts after the empty suffix.
  LATEST_KERNEL=$(dpkg-query -W -f='${Package}\n' 'linux-image-*' 2>/dev/null \
                  | grep -E '^linux-image-[0-9]' \
                  | grep -v -- '-unsigned$' \
                  | sed 's/^linux-image-//' \
                  | sort -V | tail -n1)
  if [[ -n "${LATEST_KERNEL}" && "${LATEST_KERNEL}" != "${RUNNING_KERNEL}" ]]; then
    BLOCKERS+=("running kernel (${RUNNING_KERNEL}) is older than installed kernel (${LATEST_KERNEL})")
    REBOOT_NEEDED=1
  fi

  # --- BT subsystem ---
  # If the onboard BT chip is disabled in config.txt, remove the overlay.
  # The device-tree change only takes effect at boot, so we must reboot
  # before bluetoothd can find the chip.
  local cfg
  for cfg in /boot/firmware/config.txt /boot/config.txt; do
    if [[ -f "$cfg" ]] && grep -qE '^[[:space:]]*dtoverlay=disable-bt[[:space:]]*$' "$cfg"; then
      say "Removing dtoverlay=disable-bt from $cfg (onboard BT was disabled)"
      run "sed -i -E '/^[[:space:]]*dtoverlay=disable-bt[[:space:]]*\$/d' $cfg"
      AUTOFIXED+=("removed dtoverlay=disable-bt from $cfg")
      REBOOT_NEEDED=1
    fi
  done

  # Re-enable hciuart on Pi-family images. install-radiomodule.sh disables
  # both `disable-bt` AND `hciuart.service`, so removing the overlay alone
  # wouldn't bring the BT chip up — hciuart is what btattach's the BCM
  # combo chip to the kernel. On Pi 5 the unit doesn't exist (BT comes
  # up differently), so we skip there.
  if systemctl list-unit-files hciuart.service >/dev/null 2>&1 \
     && systemctl list-unit-files hciuart.service | grep -q hciuart.service; then
    if ! systemctl is-enabled --quiet hciuart.service 2>/dev/null; then
      say "Enabling hciuart.service (was disabled — explains hci0 not appearing)"
      run "systemctl enable hciuart.service"
      AUTOFIXED+=("enabled hciuart.service")
      REBOOT_NEEDED=1
    fi
  fi

  # --- Report + maybe-bail ---
  if (( ${#BLOCKERS[@]} == 0 && ${#AUTOFIXED[@]} == 0 )); then
    say "All prerequisites satisfied — proceeding with install"
    rm -f "${upgrade_out}"
    return 0
  fi

  say ""
  say "STOP — the system isn't ready to install Bluetooth yet."
  say ""
  if (( ${#BLOCKERS[@]} > 0 )); then
    say "Issues you need to address:"
    local b
    for b in "${BLOCKERS[@]}"; do say "  - ${b}"; done
    say ""
  fi
  if (( ${#AUTOFIXED[@]} > 0 )); then
    say "Auto-fixed (takes effect on next boot):"
    local a
    for a in "${AUTOFIXED[@]}"; do say "  - ${a}"; done
    say ""
  fi
  if (( APT_UPGRADE_NEEDED )); then
    say "First 10 pending packages:"
    grep '^Inst ' "${upgrade_out}" | head -10 | sed 's/^Inst /  - /'
    if [[ "${PENDING}" -gt 10 ]]; then
      say "  ... and $((PENDING - 10)) more"
    fi
    say ""
  fi
  say "Recovery — run these in order:"
  say ""
  if (( APT_UPGRADE_NEEDED )); then
    say "    sudo apt -y update && sudo apt -y upgrade"
  fi
  if (( REBOOT_NEEDED )); then
    say "    sudo reboot"
  fi
  say "    ${INSTALLER_NAME}"
  say ""
  if (( ${#AUTOFIXED[@]} > 0 )); then
    say "(Nothing else has been changed on this run — packages, BlueZ tuning,"
    say "and hotspot-bluetooth will be installed on the post-reboot run.)"
  fi
  rm -f "${upgrade_out}"
  exit 0
}

ensure_ready_to_install

say "Installing Bluetooth prerequisites"
run "apt install -y bluez python3-dbus python3-gi wget rfkill"

say "Unblocking bluetooth (rfkill)"
run "rfkill unblock bluetooth"

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

# 4G + BT combo-chip workaround: install-4gmodule's old disable-wlan
# brings wlan0 down at the netdev layer, which on the BCM43430A1
# combo radio kills BT LE advertising (RegisterAdvertisement returns
# Failed). Refresh the 4G-stack files that have wlan-handling baked in,
# so they use the BT-aware /usr/sbin/wlan-state helper that keeps the
# netdev up when BT is installed. Idempotent; only fires when 4G is
# already installed.
if [[ -f /usr/sbin/hotspot-4g ]]; then
  say "4G stack detected — refreshing wlan-handling files (combo-chip BT fix)"
  run "wget -O /usr/sbin/wlan-state $RAW/wlan-state"
  run "chmod +x /usr/sbin/wlan-state"
  run "wget -O /usr/sbin/hotspot-4g $RAW/hotspot-4g"
  run "chmod +x /usr/sbin/hotspot-4g"
  run "wget -O /usr/sbin/hotspot-4g-monitor $RAW/hotspot-4g-monitor"
  run "chmod +x /usr/sbin/hotspot-4g-monitor"
  run "wget -O /etc/systemd/system/disable-wlan.service $RAW/disable-wlan.service"
  # If the timer already fired before we updated the unit, wlan0 is
  # currently down at netdev level — bring it back up now so BT can
  # register its advertisement this run.
  run "/usr/sbin/wlan-state up"
fi

say "Enable and start hotspot-bluetooth"
run "systemctl daemon-reload"
run "systemctl enable hotspot-bluetooth"
run "systemctl restart hotspot-bluetooth"

say "Done. Advertising as $(hostname)"
