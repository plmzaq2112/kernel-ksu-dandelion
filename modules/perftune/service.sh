#!/system/bin/sh
# perftune: runtime tuning, applied in stable phase to avoid competing with
# the early-boot storm (zygote fork burst ~ first 60-90s spikes CPU/swap).
MODDIR=${0%/*}

# 1) wait for boot, 2) then let the startup storm subside before tuning.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
echo "perftune: boot_completed, waiting for startup storm to subside..." >> /data/perftune.log
sleep 150

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

# Swap: swappiness 60 -> 100 for 4GB RAM + 2GB zram: keep anonymous pages
# compressible in zram (cheap, RAM-backed) instead of trimming file cache
# under pressure. page-cluster=0 (single-page) matches zram random access.
sysctl -w vm.swappiness=100

# Low-memory watermark: stock 7711 kB leaves almost no free pages before
# kswapd triggers; 16384 kB gives the allocator headroom for bursts and
# avoids order>0 allocation stalls / OOM front-line.
sysctl -w vm.min_free_kbytes=16384

# VFS cache: 200 releases dentry/inode caches too aggressively (hurts cold
# app start). 100 = balanced.
sysctl -w vm.vfs_cache_pressure=100

# Readahead: 128KB -> 512KB sequential-read prefetch; faster cold app start.
[ -w /sys/block/mmcblk0/queue/read_ahead_kb ] && \
    echo 512 > /sys/block/mmcblk0/queue/read_ahead_kb

# Dirty pages: eMMC has no SLC write cache to absorb burst flushes, so cap
# dirty pages low to avoid periodic writeback storms (5%/20% stock = up to
# ~200MB/780MB of accumulated dirty data on 4GB RAM).
sysctl -w vm.dirty_background_ratio=3
sysctl -w vm.dirty_ratio=15
DR=$(cat /proc/sys/vm/dirty_ratio)
DB=$(cat /proc/sys/vm/dirty_background_ratio)

# KSM: pages_to_scan alone does nothing until run=1 (stock has run=0 = off).
# Enable merging + keep a moderate scan rate to dedup mmap-heavy apps.
if [ -w /sys/kernel/mm/ksm/run ]; then
    echo 1 > /sys/kernel/mm/ksm/run
fi
if [ -w /sys/kernel/mm/ksm/pages_to_scan ]; then
    echo 1000 > /sys/kernel/mm/ksm/pages_to_scan
fi

# THP khugepaged: default 10s scan interval amortizes the hugepage work;
# double it since KSM+THP together would otherwise keep waking during app
# churn. Hugepage formation still works, just less eagerly.
[ -w /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs ] && \
    echo 20000 > /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs

# log
echo "[perftune] applied $CC tcp_fastopen=3 swappiness=100 minfree=16384 cachepressure=100 dirty=$DR/$DB readahead=512 ksm=1000" >> /data/perftune.log