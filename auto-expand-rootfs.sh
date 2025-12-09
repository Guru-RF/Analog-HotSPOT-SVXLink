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

# Get parent disk and partition number via lsblk
DISK="/dev/$(lsblk -no PKNAME "$ROOT_DEV")"
PART_NUM="$(lsblk -no PARTNUM "$ROOT_DEV")"

if [[ -z "$DISK" || -z "$PART_NUM" ]]; then
  log "Could not determine parent disk or partition number."
  exit 1
fi

log "Disk: $DISK, partition: $PART_NUM"

# Make sure this partition is the last one on the disk
MAX_PART_NUM="$(lsblk -nro PARTNUM "$DISK" | grep -E '^[0-9]+$' | sort -n | tail -n1 || true)"

if [[ -z "$MAX_PART_NUM" ]]; then
  log "No partition numbers found on $DISK; aborting."
  exit 1
fi

if [[ "$PART_NUM" != "$MAX_PART_NUM" ]]; then
  log "Root partition is not the last partition on the disk (max is $MAX_PART_NUM). Not expanding."
  # Disable ourselves: nothing useful to do automatically
  systemctl disable auto-expand-rootfs.service >/dev/null 2>&1 || true
  exit 0
fi

# Check sizes (bytes)
DISK_SIZE="$(lsblk -bno SIZE "$DISK")"
PART_SIZE="$(lsblk -bno SIZE "$ROOT_DEV")"

if [[ -z "$DISK_SIZE" || -z "$PART_SIZE" ]]; then
  log "Could not read disk or partition size."
  exit 1
fi

FREE_BYTES=$((DISK_SIZE - PART_SIZE))
# Require at least 8 MiB extra space to bother
MIN_SLACK=$((8 * 1024 * 1024))

log "Disk size: $DISK_SIZE bytes, partition size: $PART_SIZE bytes, free: $FREE_BYTES bytes"

if (( FREE_BYTES < MIN_SLACK )); then
  log "No significant extra space detected. Not expanding."
  systemctl disable auto-expand-rootfs.service >/dev/null 2>&1 || true
  exit 0
fi

log "Extra space detected. Attempting to expand partition and filesystem..."

# Grow partition to fill disk
# Note: parted must be installed.
if ! command -v parted >/dev/null 2>&1; then
  log "parted not found; cannot expand partition."
  exit 1
fi

# Some parted versions need a "Yes" confirmation when moving the end;
# using -s avoids asking for input.
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

# Now expand filesystem (assumes ext4; adjust if using xfs, btrfs, etc.)
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
