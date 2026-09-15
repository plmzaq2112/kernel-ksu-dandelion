# KernelSU for Redmi 9A (dandelion) — MT6765 / 4.19.275

GKI-less (non-GKI) direct integration of [KernelSU v3.3.0](https://github.com/tiann/KernelSU)
into the stock MediaTek 4.19.275 kernel, flashed into the boot image.
Built and verified on a **Redmi 9A (dandelion, Helio G25 / MT6765)** running an **Android 13/14 GSI** (phh treble).

**#48b status: fully working — "complete kernel" build.** SELinux stays **permissive** for full
developer freedom (capabilities fully open, root = `uid=0(root)` under `u:r:su:s0`); the kernel
gains a distribution-grade feature set (`CONFIG_MODULES` + `MODVERSIONS` + `MODULE_UNLOAD`
enabled — 52 kernel modules, shipped in `ksu48b-modules.tar.gz`, auto-loaded by the `kernelmods`
KSU module on boot) on top of the enforced-upstream #47 base (enforcing still works end-to-end —
`setenforce 1; su -c id -Z` = `u:r:su:s0`, zero AVC denials).

**Status: fully working.** Manager is crowned automatically at boot, the allowlist is loaded
into kernel memory automatically (no fsck needed after reboot), and granted apps keep root
across reboots. Full root with all capabilities, plus optional enforcing if you prefer it.

## Features

- **Out-of-the-box root after boot** — no per-boot setup, no daemon dependency
- **Full user-space capability freedom** — permissive with all 39 capabilities (`CapBnd=0000003fffffffff`);
  enforcing also verified (`setenforce 1; su -c id -Z` → `u:r:su:s0`, `avc: denied` count `0`)
- **Distribution-grade feature set (#48)** — 52 kernel modules shipped & auto-loaded on boot:
  **14 extra filesystems** (vfat/squashfs/xfs/hfs+/iso9660/minix/nilfs2/ntfs3/reiserfs/udf/jfs/btrfs...),
  **network tunnelling** (VXLAN, GENEVE, VLAN 802.1Q, GRE), **traffic shaping** (htb/netem/tbf/red/sfq/prio),
  **storage & crypto** (dm-crypt/dm-cache/dm-thin/dm-raid/md RAID0/1/10/456), **zram** swap, more
- **Automatic Manager crown** — `me.weishu.kernelsu` (v2-only resign is REQUIRED, see below) is
  detected via APK v2 signature scan every 30s until found, then granted the kernel fd
- **Automatic allowlist load** — the kernel loads `/data/adb/ksu/.allowlist` into memory itself
  once `/data` is ready (the v3 Manager never delivers the `post-fs-data` REPORT_EVENT on this
  GSI setup, so upstream relies on it and loses all grants on reboot — this build self-loads)
- **su redirection (sucompat)** patched in at 90s post-boot to survive the early exec storm
- **ksu_cred init** (`#47`) — `cache_sid()+setup_ksu_cred()` run from the throne tracker so an
  enforcing kernel can `filp_open()` ksud (`open ksud err: -13` root cause, fixed)
- **fsnotify crash fix** (`#46`) — `pkg_observer.c` guards `file_name < PAGE_SIZE` (the 4.19
  old-callback `strlen` crash that bootlooped the #45 build)
- **reboot magic（fd install）** — `reboot(MAGIC1, MAGIC2, 0, &fdout)` installs the KernelSU fd
- **No kprobes / no ftrace syscall tracepoints required** — syscall table slots are patched
  directly (this stock MTK kernel has no `CONFIG_FTRACE_SYSCALLS`)
- **KernelSU Manager grants persist across reboots**

## Requirements

| What | Value |
|---|---|
| Device | Redmi 9A / Poco C3 / Redmi 9C etc. (dandelion/angelican/cattail, MT6765) |
| Boot partition | `/dev/block/mmcblk0p33` |
| ROM (tested) | Android 13/14 GSI (phh treble), bootloader unlocked, **SELinux permissive (or enforcing — both verified)** |
| RAM | root shell needed once to `dd` the image (use `adb root`) |

> **Not a standalone KernelSU**, unlike kernel-flasher/KSUD packages: this is a kernel built with
> KernelSU compiled in. The adjust image works only on this boot image layout
> (page_size 2048 / header v2, which is what the stock MT6765 boot images use).

## Download

Grab the release assets from the **Releases** page of this repo:
`boot-4.19.275-mt6765-ksu48b-perm.img` (the **#48b** build — complete kernel; + `.sha256`),
`ksu48b-modules.tar.gz` (52 kernel modules; extract to `/data/adb/ksu-modules/`),
`KernelSU_v3.3.0_32601_gkipatched_v2only.apk` (+ `.idsig`).
Place the image next to `flash/flash.bat` / `flash/flash.sh` (they look for it there).

## Install

1. Unlock bootloader.
2. On Windows: `flash\flash.bat` — or do it by hand (Linux/macOS `flash\flash.sh`),
   or adb-only:
   ```bash
   readlink /dev/block/by-name/boot        # expect /dev/block/mmcblk0p33   (verify on YOUR device!)
   adb push boot-4.19.275-mt6765-ksu48b-perm.img /data/local/tmp/boot.img
   adb root && adb wait-for-device
   adb shell dd if=/data/local/tmp/boot.img of=/dev/block/mmcblk0p33 bs=4096 conv=fsync
   adb reboot
   ```
3. (optional, complete-kernel modules) after reboot:
   ```bash
   adb shell mkdir -p /data/adb/ksu-modules
   adb push ksu48b-modules.tar.gz /data/local/tmp/modules.tar.gz
   adb shell "cd /data/adb/ksu-modules && tar xzf /data/local/tmp/modules.tar.gz"
   # kernelmods KSU module is included as /data/adb/modules/kernelmods/ is auto-run on boot;
   # or run once manually:  adb shell sh /data/adb/modules/kernelmods/service.sh
   ```
4. First boot afterwards: wait ~60-120s (the tracker retries every 30s for up to 10 times).
   `adb shell dmesg | grep -iE 'Crowning|load_allow_uid|stage2|Cached su'` should show
   `Crowning manager: me.weishu.kernelsu`, the `load_allow_uid` lines for your granted apps,
   and `Cached su SID` (ksu_cred init).
5. **Install the Manager app** (see below), grant root to it, then grant whatever you want.

### Required Manager app

The stock KernelSU Manager APK is signed with modern v3 sig; the `is_manager_apk` check on
this non-GKI kernel catches the v3-only signature and refuses to crown it. You **must** use:

> **`KernelSU_v3.3.0_32601_gkipatched_v2only.apk`** (on the Releases page, `apk/` keeps its sha256)

It is the same GKI-patched v3.3.0 app, **re-signed with v2-only scheme**
(`apksigner --v2-signing-enabled true --v3-signing-enabled false`), so the kernel recognizes it.
`reboot()` after installing it if the crown was refused earlier.

## Repository layout

```
flash/            boot image .sha256 and flash scripts  (image itself: Releases page)
apk/              required resign (v2-only) Manager app .sha256     (apk itself: Releases page)
patches/          ksu43_kernelsu.patch  — clean upstream diff (KernelSU v3.3.0 -> ours, 7 files)
patches/final-kernel-patches/  — the 7 modified files in full
scripts/          local build scripts (toolchain/tool paths are machine-specific — adjust)
docs/KERNELS.md   full build/log/troubleshooting notes (author's journal)
```

## Runtime performance tuning (safe, no-kernel-rebuild)

The #48b kernel is the **only** verified-bootable config build on this device: any attempt to
re-enable compile-time features that require a vmlinux rebuild (THP, KVM, JUMP_LABEL, CE crypto
builtins — experiments #49/#49b/#50) panics at boot, because the KernelSU direct syscall-table
patch then lands in a read-only page (`Unable to handle kernel write to read-only memory`).
Performance gains are therefore shipped as **runtime-only "add-ons"**, all applied by the
`kernelmods` KSU module's tune section at boot (log: `/data/adb/kernelmods.log`):

| Item | Value | Measured benefit |
|---|---|---|
| eMMC I/O scheduler | `kyber` | sequential read **294 → 941 MB/s (3.2x)**; revert: `echo mq-deadline` |
| TCP congestion control | `bbr` | better weak-network / cellular throughput |
| TCP rmem / wmem | 4096 87380 6291456 / 4096 16384 4194304 | larger windows, higher throughput |
| tcp_fastopen | 3 | saves an RTT per connection |
| tcp_window_scaling / timestamps / sack | 1 | integrity on high-latency links |
| net.core.somaxconn | 128 → 4096 | connection backlog capacity |
| tcp_max_syn_backlog | 128 → 512 | SYN queue depth (jitter resilience) |
| vm/page-cluster | 0 | complements vendor swappiness=80 + zram preset |
| vm/min_free_kbytes | 7708 → 8192 | low-memory watermark protection |

Rollback: pre-tune script is kept on-device as `/data/adb/modules/kernelmods/service.sh.bak2026`.

## Building from source

See `docs/KERNELS.md` for the full story. Short version:

```bash
export PATH=/usr/lib/llvm-18/bin:$PATH
bash scripts/build_ksu25_v2.sh   # expects a MediaTek 4.19 source tree at $OSRC
```

- Kernel: 4.19.275-mt6765 (Mi MT6765 kernel source)
- Toolchain: Ubuntu clang/LLD 18
- Image packing: `scripts/pack_boot.py` (page_size 2048, header v2, ramdisk replaced)
- cmdline gains `androidboot.selinux=permissive` (see `scripts/perm_cmdline.py`)

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

## Known issues / notes

- **SELinux**: the #48b build boots **permissive** (developer "complete root" mode — all
  capabilities open, modules insmod freely). Enforcing is fully verified on the same kernel
  (`setenforce 1; su -c id -Z` → `u:r:su:s0`, `avc: denied` = 0) if you need it; keep permissive
  if you want the module/driver freedom.
- **Modules**: loading 52 modules taints the kernel (`bad vermagic` / `kernel tainted` dmesg —
  `CONFIG_MODULE_SIG=n`), harmless. `rmmod` works at the syscall level but user-space policy
  may block it; a reboot resets to a clean module table.
- **Root detection**: `/system/bin/su` is a ksud clone and `su -v` echoes `3.3.0:KernelSU`;
  the GSI is userdebug (`ro.debuggable=1`). Lightweight detectors will flag root. This is a
  dev/root build, not an anti-detection build.
- First boot after flashing may take longer; don't reboot during the first 2 minutes.
- If you later see "all grants lost", that was this missing-self-load bug — it is fixed here.
  To validate a fresh boot, `adb shell dmesg | grep load_allow_uid`.
- This is provided **as-is**, root access, flashing and everything else at your own risk.

## Credits / license

- [KernelSU](https://github.com/tiann/KernelSU) by tiann — GPL-2.0; this project adapts
  v3.3.0 to a non-GKI MTK kernel.
- The GKI patch workflow this build is based on: KernelSU's own `build-ksu-dir` tooling.
- Everything else here follows the kernel's GPL-2.0 (MediaTek kernel source is GPL).

**Not affiliated with Xiaomi, Google, or KernelSU.**