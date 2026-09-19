#!/system/bin/sh
# =============================================================================
# perftune v2 - unified runtime tuning module for Redmi 9A (dandelion) kernel
# #61/#62 builds (io_uring/BFQ/KSM/THP/HZ1000/BBR). Applied once the early-boot
# storm has subsided so it never competes with the zygote fork burst.
#
# Sections:
#   1. wait for boot + storm window
#   2. rollback handling (if /data/perftune.rollback exists)
#   3. first-run snapshot of stock defaults to /data/perftune-orig
#   4. apply all knobs (net / memory / dirty / storage / KSM / THP)
#   5. status log
# =============================================================================
MODDIR=${0%/*}
LOG=/data/perftune.log
ORIG=/data/perftune-orig
ROLLBACK=/data/perftune.rollback

say() { echo "[perftune] $*" >> "$LOG"; }

# --- 1. wait for boot + storm window -------------------------------------
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
say "boot_completed, waiting for startup storm to subside..."
sleep 150

# --- 2. rollback: restore stock values and exit --------------------------
if [ -f "$ROLLBACK" ]; then
    say "rollback requested, restoring snapshot from $ORIG"
    if [ -f "$ORIG" ]; then
        while IFS='=' read -r k v; do
            [ -z "$k" ] && continue
            case "$k" in
                read_ahead_mmc)  [ -w /sys/block/mmcblk0/queue/read_ahead_kb ] && echo "$v" > /sys/block/mmcblk0/queue/read_ahead_kb ;;
                sched_mmc)       [ -w /sys/block/mmcblk0/queue/scheduler ] && echo "$v" > /sys/block/mmcblk0/queue/scheduler ;;
                ksm_run)         [ -w /sys/kernel/mm/ksm/run ] && echo "$v" > /sys/kernel/mm/ksm/run ;;
                ksm_pages)       [ -w /sys/kernel/mm/ksm/pages_to_scan ] && echo "$v" > /sys/kernel/mm/ksm/pages_to_scan ;;
                khugepaged_scan) [ -w /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs ] && echo "$v" > /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs ;;
                *)               sysctl -w "$k=$v" 2>/dev/null ;;
            esac
        done < "$ORIG"
    fi
    rm -f "$ROLLBACK"
    say "rollback complete"
    exit 0
fi

# --- 3. first-run snapshot of stock defaults ------------------------------
if [ ! -f "$ORIG" ]; then
    {
        echo "net.ipv4.tcp_congestion_control=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)"
        echo "net.ipv4.tcp_fastopen=$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null)"
        echo "net.core.somaxconn=$(sysctl -n net.core.somaxconn 2>/dev/null)"
        echo "net.ipv4.tcp_max_syn_backlog=$(sysctl -n net.ipv4.tcp_max_syn_backlog 2>/dev/null)"
        echo "net.ipv4.tcp_rmem=$(sysctl -n net.ipv4.tcp_rmem 2>/dev/null)"
        echo "net.ipv4.tcp_wmem=$(sysctl -n net.ipv4.tcp_wmem 2>/dev/null)"
        echo "net.ipv4.tcp_window_scaling=$(sysctl -n net.ipv4.tcp_window_scaling 2>/dev/null)"
        echo "net.ipv4.tcp_timestamps=$(sysctl -n net.ipv4.tcp_timestamps 2>/dev/null)"
        echo "net.ipv4.tcp_sack=$(sysctl -n net.ipv4.tcp_sack 2>/dev/null)"
        echo "vm.swappiness=$(sysctl -n vm.swappiness 2>/dev/null)"
        echo "vm.min_free_kbytes=$(sysctl -n vm.min_free_kbytes 2>/dev/null)"
        echo "vm.vfs_cache_pressure=$(sysctl -n vm.vfs_cache_pressure 2>/dev/null)"
        echo "vm.page-cluster=$(sysctl -n vm.page-cluster 2>/dev/null)"
        echo "vm.dirty_ratio=$(sysctl -n vm.dirty_ratio 2>/dev/null)"
        echo "vm.dirty_background_ratio=$(sysctl -n vm.dirty_background_ratio 2>/dev/null)"
        echo "read_ahead_mmc=$(cat /sys/block/mmcblk0/queue/read_ahead_kb 2>/dev/null)"
        echo "sched_mmc=$(cat /sys/block/mmcblk0/queue/scheduler 2>/dev/null | sed 's/.*\[\(.*\)\].*/\1/')"
        echo "ksm_run=$(cat /sys/kernel/mm/ksm/run 2>/dev/null)"
        echo "ksm_pages=$(cat /sys/kernel/mm/ksm/pages_to_scan 2>/dev/null)"
        echo "khugepaged_scan=$(cat /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs 2>/dev/null)"
    } > "$ORIG"
    say "saved stock snapshot to $ORIG"
fi

# --- 4. apply all knobs ----------------------------------------------------

# --- network / TCP ---
if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    CC=bbr
else
    CC=cubic
fi
sysctl -w net.ipv4.tcp_congestion_control=$CC
sysctl -w net.ipv4.tcp_fastopen=3
sysctl -w net.core.somaxconn=4096
sysctl -w net.ipv4.tcp_max_syn_backlog=512
sysctl -w net.ipv4.tcp_rmem='4096 87380 6291456'
sysctl -w net.ipv4.tcp_wmem='4096 16384 4194304'
sysctl -w net.ipv4.tcp_window_scaling=1
sysctl -w net.ipv4.tcp_timestamps=1
sysctl -w net.ipv4.tcp_sack=1

# --- memory / swap ---
sysctl -w vm.swappiness=100
sysctl -w vm.min_free_kbytes=16384
sysctl -w vm.vfs_cache_pressure=100
sysctl -w vm.page-cluster=0
sysctl -w vm.dirty_background_ratio=3
sysctl -w vm.dirty_ratio=15

# --- I/O scheduler: prefer BFQ (kernel #61 built-in), fall through silently ---
if [ -w /sys/block/mmcblk0/queue/scheduler ]; then
    SCHED=$(cat /sys/block/mmcblk0/queue/scheduler)
    if echo "$SCHED" | grep -qw bfq; then
        echo bfq > /sys/block/mmcblk0/queue/scheduler
    fi
fi

# --- storage readahead ---
[ -w /sys/block/mmcblk0/queue/read_ahead_kb ] && \
    echo 512 > /sys/block/mmcblk0/queue/read_ahead_kb

# --- KSM (needs run=1 to actually merge) ---
[ -w /sys/kernel/mm/ksm/run ] && echo 1 > /sys/kernel/mm/ksm/run
[ -w /sys/kernel/mm/ksm/pages_to_scan ] && echo 1000 > /sys/kernel/mm/ksm/pages_to_scan

# --- THP khugepaged: halve scan wakeups ---
[ -w /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs ] && \
    echo 20000 > /sys/kernel/mm/transparent_hugepage/khugepaged/scan_sleep_millisecs

# --- 5. status + current-memory log ---
MA=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
SWU=$(awk '/zram0/{print $4}' /proc/swaps)
PS=$(awk '/^some/{printf "%s/%s/%s",$3,$4,$5}' /proc/pressure/memory)
say "applied CC=$CC fastopen=3 swappiness=100 minfree=16384 dirty=15/3 sched=bfq readahead=512 ksm=1 khugepaged=20000"
say "status free=${MA}kB zram_used=${SWU}kB psi_some=$PS"