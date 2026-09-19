# perftune v2

Unified runtime tuning module (KernelSU) for the dandelion / Redmi 9A kernel builds
**#61/#62** (io_uring / BFQ / KSM / THP / HZ1000 / BBR). Applied **after the early-boot
storm** so tuning never competes with the zygote fork burst.

## Files

| file | purpose |
|---|---|
| `service.sh` | waits for `sys.boot_completed` + 150 s, then applies all knobs |
| `customize.sh` | install hook (logs install, safe to reinstall/upgrade) |
| `module.prop` | module metadata (v2) |

## Install

`adb root` + copy the folder to `/data/adb/modules/perftune/`, or zip it and flash in KernelSU Manager.

## What it applies

- **Network**: BBR (cubic fallback), FastOpen=3, somaxconn=4096, max_syn_backlog=512,
  rmem/wmem buffers, window_scaling/timestamps/sack on.
- **Memory**: swappiness=100, min_free_kbytes=16384, vfs_cache_pressure=100,
  page-cluster=0, dirty_ratio=15, dirty_background_ratio=3.
- **Storage**: mmcblk0 scheduler → **bfq**, read_ahead_kb=512.
- **Scheduler (EAS/CFS, merged from sched-eas v1)**: CFS wakeup_granularity 1 ms,
  min_granularity 1.5 ms, latency 8 ms (faster tap/app response); MTK uclamp
  foreground floor **50** / background **0** on `eas_ctrl` (fg never starved below
  mid-frequency, battery-safe).
- **KSM**: `run=1` (merging actually enabled; stock has run=0 so pages_to_scan alone
  does nothing), pages_to_scan=1000.
- **THP**: khugepaged `scan_sleep_millisecs` 10000 → **20000** (halve scan wakeups while
  KSM+THP are both active).

## First boot snapshot & rollback

On first boot the real stock defaults are snapshotted to `/data/perftune-orig`
(before any knobs are applied), so a rollback always returns to the genuine defaults.

```sh
adb shell touch /data/perftune.rollback   # request rollback
adb reboot
```

The module restores every value from the snapshot and exits (no re-tuning). Removing the
module returns the device to stock automatically, because all knobs live in `/proc`/`/sys`
and reset on reboot. Logs: `/data/perftune.log`, snapshot: `/data/perftune-orig`.