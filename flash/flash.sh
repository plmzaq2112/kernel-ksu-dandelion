#!/usr/bin/env bash
# Flash boot_ksu43_load.img on Redmi 9A (dandelion, MT6765)
# Requires: adb, a device with unlocked bootloader and adb root working.
set -euo pipefail
IMG="${1:-$(dirname "$0")/boot_ksu43_load.img}"
BOOT_DEV="/dev/block/mmcblk0p33"

echo "== verify image =="
sha256sum -c "$IMG.sha256"

echo "== push =="
adb push "$IMG" /data/local/tmp/boot.img

echo "== verify boot partition target (readlink /dev/block/by-name/boot) =="
adb root >/dev/null
adb wait-for-device
adb shell "readlink /dev/block/by-name/boot" || true
echo "REVIEW the line above: it MUST be ${BOOT_DEV} unless you change BOOT_DEV."

read -rp "press Enter to flash to ${BOOT_DEV} ... " _

echo "== flash =="
adb shell "dd if=/data/local/tmp/boot.img of=${BOOT_DEV} bs=4096 conv=fsync"
echo "== reboot =="
adb reboot
echo "Reconnect and check:"
echo "  adb root && adb shell dmesg | grep -iE 'Crowning|load_allow_uid|stage2'"
echo "Expected within ~60-120s: 'Crowning manager: me.weishu.kernelsu(uid=...)'"