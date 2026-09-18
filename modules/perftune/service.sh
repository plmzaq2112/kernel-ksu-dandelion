#!/system/bin/sh
# perftune: A-tier runtime tuning, applied late in boot (failsafe)
MODDIR=${0%/*}
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done

# TCP congestion control: prefer BBR (available from kernel #62); fall back to
# cubic on older kernels. Available checked live via tcp_available_congestion_control.
if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    CC=bbr
else
    CC=cubic
fi
sysctl -w net.ipv4.tcp_congestion_control=$CC

# TCP Fast Open: 3 = enable for both client and server side.
# Shaves one RTT on connection establishment (network acceleration, zero risk)
if [ "$(cat /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null)" != "3" ]; then
    echo 3 > /proc/sys/net/ipv4/tcp_fastopen
fi

# Swap: swappiness 80 -> 60 reduces thrashing with zram, snappier foreground
sysctl -w vm.swappiness=60

# VFS cache: 200 releases dentry/inode caches too aggressively (hurts cold
# app start). 100 = balanced.
sysctl -w vm.vfs_cache_pressure=100

# Readahead: 128KB -> 512KB sequential-read prefetch; faster cold app start.
[ -w /sys/block/mmcblk0/queue/read_ahead_kb ] && \
    echo 512 > /sys/block/mmcblk0/queue/read_ahead_kb

# KSM: speed up dedup scan (default 100 pages/20ms is very conservative).
# 1000/20ms keeps CPU cost low while deduping mmap-heavy apps far faster.
if [ -w /sys/kernel/mm/ksm/pages_to_scan ]; then
    echo 1000 > /sys/kernel/mm/ksm/pages_to_scan
fi

# log
echo "[perftune] applied $CC tcp_fastopen=3 swappiness=60 cachepressure=100 readahead=512 ksm=1000" >> /data/perftune.log