# KernelSU for Redmi 9A (dandelion) — MT6765 / 4.19.275

GKI-less (non-GKI) direct integration of [KernelSU v3.3.0](https://github.com/tiann/KernelSU)
into the stock MediaTek 4.19.275 kernel, flashed into the boot image.
Built and verified on a **Redmi 9A (dandelion, Helio G25 / MT6765)** running an **Android 14 GSI** (phh treble, SELinux permissive).

**Status: fully working.** Manager is crowned automatically at boot, the allowlist is loaded
into kernel memory automatically (no fsck needed after reboot), and granted apps keep root
across reboots.

## Features

- **Out-of-the-box root after boot** — no per-boot setup, no daemon dependency
- **Automatic Manager crown** — `me.weishu.kernelsu` (v2-only resign is REQUIRED, see below) is
  detected via APK v2 signature scan every 30s until found, then granted the kernel fd
- **Automatic allowlist load** — the kernel loads `/data/adb/ksu/.allowlist` into memory itself
  once `/data` is ready (the v3 Manager never delivers the `post-fs-data` REPORT_EVENT on this
  GSI setup, so upstream relies on it and loses all grants on reboot — this build self-loads)
- **su redirection (sucompat)** patched in at 90s post-boot to survive the early exec storm
- **reboot magic (fd install)** — `reboot(MAGIC1, MAGIC2, 0, &fdout)` installs the KernelSU fd
- **No kprobes / no ftrace syscall tracepoints required** — syscall table slots are patched
  directly (this stock MTK kernel has no `CONFIG_FTRACE_SYSCALLS`)
- **KernelSU Manager grants persist across reboots**

## Requirements

| What | Value |
|---|---|
| Device | Redmi 9A / Poco C3 / Redmi 9C etc. (dandelion/angelican/cattail, MT6765) |
| Boot partition | `/dev/block/mmcblk0p33` |
| ROM (tested) | Android 14 GSI (phh treble), bootloader unlocked, SELinux permissive |
| RAM | root shell needed once to `dd` the image (use `adb root`) |

> **Not a standalone KernelSU**, unlike kernel-flasher/KSUD packages: this is a kernel built with
> KernelSU compiled in. The adjust image works only on this boot image layout
> (page_size 2048 / header v2, which is what the stock MT6765 boot images use).

## Download

Grab the latest release assets from the **Releases** page of this repo — for kernel #62 that is
`boot-4.19.275-mt6765-ksu53-perm.img` (+ `.sha256`), together with the required Manager app
`KernelSU_v3.3.0_32601_gkipatched_v2only.apk` (+ `.idsig`).
Place the image next to `flash/flash.bat` / `flash/flash.sh` (they look for it there).

## Install

1. Unlock bootloader.
2. On Windows: run `flash\flash.bat` — or do it by hand (Linux/macOS `flash/flash.sh`),
   or adb-only:
   ```bash
   readlink /dev/block/by-name/boot        # expect /dev/block/mmcblk0p33   (verify on YOUR device!)
   adb push boot-4.19.275-mt6765-ksu53-perm.img /data/local/tmp/boot.img
   adb root && adb wait-for-device
   adb shell dd if=/data/local/tmp/boot.img of=/dev/block/mmcblk0p33 bs=4096 conv=fsync
   adb reboot
   ```
3. First boot afterwards: wait ~60-120s (the tracker retries every 30s for up to 10 times).
   `adb shell dmesg | grep -iE 'Crowning|load_allow_uid|stage2'` should show
   `Crowning manager: me.weishu.kernelsu` and the `load_allow_uid` lines for your granted apps.
4. **Install the Manager app** (see below), grant root to it, then grant whatever you want.

### Required Manager app

The stock KernelSU Manager APK is signed with modern v3 sig; the `is_manager_apk` check on
this non-GKI kernel catches the v3-only signature and refuses to crown it. You **must** use:

> **`KernelSU_v3.3.0_32601_gkipatched_v2only.apk`** (on the Releases page, `apk/` keeps its sha256)

It is the same GKI-patched v3.3.0 app, **re-signed with v2-only scheme**
(`apksigner --v2-signing-enabled true --v3-signing-enabled false`), so the kernel recognizes it.
`reboot()` after installing it if the crown was refused earlier.

## Repository layout

```
flash/                   flash scripts + boot image sha256        (image itself: Releases page)
apk/                     required v2-only Manager app .sha256     (apk itself: Releases page)
scripts/build/           kernel build / config scripts (build53, sync, defconfig, ...)
scripts/pack/            boot-image packing tools (pack53, pack_boot.py, perm_cmdline.py, ...)
scripts/recover_boot.ps1 Windows fastboot restore helper
modules/perftune/        KernelSU module — runtime performance tuning (see below)
patches/ksu43_kernelsu.patch      KernelSU v3.3.0 -> ours diff (7 files)
patches/final-kernel-patches/     the 7 modified files in full
patches/perf-patches/             perf/stability changes vs vendor tree (#61/#62)
docs/KERNELS.md          full build/log/troubleshooting notes (author's journal)
```

## Building from source

```bash
export PATH=/usr/lib/llvm-18/bin:$PATH
bash scripts/build/sync.sh          # enable DEBUG_KERNEL + KALLSYMS_ALL, run olddefconfig
bash scripts/build/build53.sh       # make Image.gz (kernel #62; config spot-check below)
bash scripts/pack/pack53.sh         # pack -> boot-4.19.275-mt6765-ksu53-perm.img
```

- Kernel: 4.19.275-mt6765 (Mi MT6765 kernel source)
- Toolchain: Ubuntu clang/LLD 18
- Image packing: `scripts/pack/pack_boot.py` (page_size 2048, header v2, ramdisk replaced)
- cmdline gains `androidboot.selinux=permissive` (see `scripts/pack/perm_cmdline.py`)
- Scripts embed machine-specific paths — adjust `SRC`/`O` for your checkout.

## Kernel changes vs upstream KernelSU v3.3.0

`patches/ksu43_kernelsu.patch` (v3.3.0 → ours, ~370 lines, 7 files):

| File | Change |
|---|---|
| `hook/arm64/syscall_hook.c` | pristine `sys_call_table` image; direct slot patcher + dispatcher-style handler for no-ftrace kernels; stage1 (setresuid, reboot) / stage2 (execve*, faccessat, newfstatat) sets |
| `hook/syscall_hook_manager.c` | 90s delayed stage-2 sucompat patch; reboot hook registration; ftrace-tracepoint availability guards |
| `hook/syscall_hook.h` | new externs |
| `supercall/supercall.c` | kprobe-free fd-install route (`ksu_direct_reboot_entry`); kprobe kept for CONFIG_KPROBES builds |
| `manager/throne_tracker.c` | **allowlist auto-load** (the reboot-grants fix); 30s×10 Manager crown retry |
| `runtime/boot_event.c` | no force-crown on boot_completed (tracker handles it) |
| `core/init.c` | early `track_throne(false)` run; `MODULE_IMPORT_NS` gated to ≥5.4 (4.19 has no symbol namespaces) |

## Performance builds (#61 / #62)

In addition to the KSU integration, the kernel is performance-tuned:

| build | additions over upstream stock kernel |
|---|---|
| **#61** | io_uring (backported `fs/io_uring.c` + `CONFIG_IO_URING`), **BFQ** as default I/O scheduler, **KSM**, **THP**(`always`), **SCHED_AUTOGROUP**, **HZ=1000** |
| **#62** | **TCP BBR** compiled in and set as default congestion control — all #61 features retained |

`patches/perf-patches/` documents the 4 config/thermal changes vs the vendor tree
(BFQ default choice, io_uring Kconfig, mtk_ts_bts/dctm log demotion).

Runtime tuning is applied at boot without a rebuild by the **perftune** KernelSU module
(`modules/perftune/` — install by copying to `/data/adb/modules/perftune/`):

| setting | value |
|---|---|
| TCP congestion control | **bbr** (falls back to cubic if unavailable) |
| TCP FastOpen | `3` (client + server) |
| vm.swappiness | `60` |
| vm.vfs_cache_pressure | `100` |
| read_ahead_kb (mmcblk0) | `512` |
| KSM pages_to_scan | `1000` |

## Known issues / notes

- SELinux is **permissive** (this ROM/GKI path cannot inject its own policy on 4.19 policydb
  kernels — KernelSU's `selinux_hide` is unavailable here). This is an **engineering trade-off**,
  not a feature.
- First boot after flashing may take longer; don't reboot during the first 2 minutes.
- If you later see "all grants lost", that was this missing-self-load bug — it is fixed here.
  To validate a fresh boot, `adb shell dmesg | grep load_allow_uid`.
- This is provided **as-is**, root access, flashing and everything else at your own risk.

## Credits / license

- [KernelSU](https://github.com/tiann/KernelSU) by tiann — GPL-2.0; this project adapts
  v3.3.0 to a non-GKI MTK kernel.
- The GKI patch workflow this build is based on: KernelSU's own `build-ksu-dir` tooling.
- io_uring/BFQ/BBR/THP/KSM come from upstream Linux; everything else follows the
  kernel's GPL-2.0 (MediaTek kernel source is GPL).

**Not affiliated with Xiaomi, Google, or KernelSU.**