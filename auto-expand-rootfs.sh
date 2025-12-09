#!/usr/bin/env bash
#
# Auto-expand root filesystem to fill the disk if there is free space.
# Designed for ext4 root on a single disk (SD card, SSD, etc.).
#

set -euo pipefail

LOG_TAG="auto-expand-rootfs"

log() {
  echo "[$LOG_TAG] $*" >&2
  logger -t "$LOG_TAG" "$*"
}

# Need root
if [[ "$(id -u)" -ne 0 ]]; then
  log "Must be run as root."
  exit 1
fi

# Find root device (e.g. /dev/mmcblk0p2 or /dev/sda2)
ROOT_DEV="$(findmnt -n -o SOURCE /)"
if [[ -z "$ROOT_DEV" ]]; then
  log "Could not determine root device."
  exit 1
fi
log "Root device: $ROOT_DEV"

ROOT_BASENAME="$(basename "$ROOT_DEV")"

# Determine parent disk (e.g. /dev/mmcblk0, /dev/sda, /dev/nvme0n1)
PARENT_KNAME="$(lsblk -no PKNAME "$ROOT_DEV" 2>/dev/null || true)"
if [[ -n "$PARENT_KNAME" ]]; then
  DISK="/dev/$PARENT_KNAME"
else
  case "$ROOT_BASENAME" in
    mmcblk*p[0-9]*|nvme*n[0-9]*p[0-9]*)
      # /dev/mmcblk0p2 -> /dev/mmcblk0
      # /dev/nvme0n1p2 -> /dev/nvme0n1
      DISK="/dev/${ROOT_BASENAME%p*}"
      ;;
    *)
      # /dev/sda2 -> /dev/sda
      DISK="/dev/${ROOT_BASENAME%%[0-9]*}"
      ;;
  esac
fi

if [[ -z "$DISK" || ! -b "$DISK" ]]; then
  log "Could not determine parent disk for $ROOT_DEV."
  exit 1
fi

log "Disk: $DISK"

# Partition number = trailing digits of the device name (2 in mmcblk0p2, 3 in sda3, 10 in nvme0n1p10)
PART_NUM="$(echo "$ROOT_DEV" | grep -o '[0-9]\+$' || true)"
if [[ -z "$PART_NUM" ]]; then
  log "Could not determine partition number for $ROOT_DEV."
  exit 1
fi
log "Partition number: $PART_NUM"

# Make sure this partition is the last one on the disk
# We derive the "largest" partition number by stripping non-digits from each partition name.
MAX_PART_NUM="$(
  lsblk -nrpo NAME,TYPE "$DISK" 2>/dev/null \
  | awk '$2=="part"{gsub(/[^0-9]/,"",$1); print $1}' \
  | sort -n \
  | tail -n1 || true
)"

if [[ -z "$MAX_PART_NUM" ]]; then
  log "No partition numbers found on $DISK; aborting."
  exit 1
fi

if [[ "$PART_NUM" != "$MAX_PART_NUM" ]]; then
  log "Root partition ($PART_NUM) is not the last partition on the disk (last is $MAX_PART_NUM). Not expanding."
  systemctl disable auto-expand-rootfs.service >/dev/null 2>&1 || true
  exit 0
fi

# Check sizes (bytes)
DISK_SIZE="$(lsblk -bno SIZE "$DISK" 2>/dev/null || true)"
PART_SIZE="$(lsblk -bno SIZE "$ROOT_DEV" 2>/dev/null || true)"

if [[ -z "$DISK_SIZE" || -z "$PART_SIZE" ]]; then
  log "Could not read disk or partition size."
  exit 1
fi

FREE_BYTES=$((DISK_SIZE - PART_SIZE))
MIN_SLACK=$((8 * 1024 * 1024)) # require at least 8 MiB to bother

log "Disk size: $DISK_SIZE bytes, partition size: $PART_SIZE bytes, free: $FREE_BYTES bytes"

if (( FREE_BYTES < MIN_SLACK )); then
  log "No significant extra space detected. Not expanding."
  systemctl disable auto-expand-rootfs.service >/dev/null 2>&1 || true
  exit 0
fi

log "Extra space detected. Attempting to expand partition and filesystem..."

# Grow partition to fill disk (requires parted)
if ! command -v parted >/dev/null 2>&1; then
  log "parted not found; cannot expand partition."
  exit 1
fi

# Use partition number we derived from the device name
parted -s "$DISK" resizepart "$PART_NUM" 100% || {
  log "parted resizepart failed."
  exit 1
}

log "Partition resized, re-reading partition table…"

# Inform the kernel of partition changes
if command -v partprobe >/dev/null 2>&1; then
  partprobe "$DISK" || true
elif command -v partx >/dev/null 2>&1; then
  partx -u "$DISK" || true
else
  log "Neither partprobe nor partx found. A reboot may be required for the kernel to see new size."
fi

# Now expand filesystem (assumes ext4)
if ! command -v resize2fs >/dev/null 2>&1; then
  log "resize2fs not found; cannot resize ext4 filesystem."
  exit 1
fi

log "Resizing ext4 filesystem on $ROOT_DEV..."
resize2fs "$ROOT_DEV"

log "Filesystem expansion completed successfully."

# Disable this service so it only runs once
systemctl disable auto-expand-rootfs.service >/dev/null 2>&1 || true
log "Service auto-expand-rootfs.service disabled for future boots."

exit 0
