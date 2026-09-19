#!/system/bin/sh
# perftune v2 install hook.
# The real stock snapshot is taken on first boot by service.sh (kernel defaults
# are only readable after an early-boot /proc is populated). Nothing to do here
# except log that we installed; keep the module safe to install/upgrade.
echo "[perftune] installed v2 (params applied after boot storm on next boot)" >> /data/perftune.log