[ROM][KERNEL][ANDROID 14 GSI] KernelSU v3.3.0 integrated kernel for Redmi 9A (dandelion) — MT6765 / 4.19.275

**Complete KernelSU build that survives reboots.** No kernel-flasher, no daemon,
no per-boot setup: boot once and the Manager is crowned automatically and your
allowlist is loaded back into memory by the kernel itself.

- **Device:** Redmi 9A / dandelion (MT6765, Helio G25)
- **Kernel:** 4.19.275-mt6765 (MediaTek stock source, clang 18)
- **ROM tested on:** Android 14 GSI (phh treble), SELinux permissive
- **KernelSU:** v3.3.0 (api 2), integrated (CONFIG_KSU is built in)
- **Status:** FINAL — tested, grants persist across reboots

**Features**
- Auto crown of the Manager app at boot (v2-sig app-scan, 30s x10 retry)
- **Auto-load of the allowlist** (fix for "my grants disappear after reboot" —
  upstream v3 relies on a userspace REPORT_EVENT that never arrives on this GSI
  path; this build loads `/data/adb/ksu/.allowlist` from inside the kernel once
  `/data` is ready)
- su → ksud redirection (sucompat) patched in at 90s (sidesteps the early-boot
  exec-storm panics on MTK)
- Reboot-magic fd install (`reboot(MAGIC1,MAGIC2,0,&out)`)
- **No kprobes / no ftrace tracepoints needed** — hooks patch the syscall table
  directly (this stock MTK kernel lacks CONFIG_FTRACE_SYSCALLS)

**Downloads**
- boot image: boot_ksu43_load.img (flash boot slot, see below)
- Required Manager: KernelSU_v3.3.0_32601_gkipatched_v2only.apk (REQUIRED —
  the standard/stock Manager apk is v3-signed and the non-GKI kernel rejects it,
  this is the same app re-signed v2-only)
- Source patches: ksu43_kernelsu.patch (KernelSU v3.3.0 → our port, 7 files)

**Flash (needs unlocked bootloader + adb)**
1. `readlink /dev/block/by-name/boot` → confirm it's `/dev/block/mmcblk0p33` on YOUR unit
2. `adb push boot_ksu43_load.img /data/local/tmp/boot.img`
3. `adb root`
4. `adb shell dd if=/data/local/tmp/boot.img of=/dev/block/mmcblk0p33 bs=4096 conv=fsync`
5. `adb reboot`
6. Wait ~60–120s, then verify: `adb shell dmesg | grep -iE 'Crowning|load_allow_uid|stage2'`
   → expect `Crowning manager: me.weishu.kernelsu(uid=...)` and `load_allow_uid ...` for your apps.

**Notes**
- SELinux runs permissive because this GSI/4.19-policydb path can't inject policy
  (KernelSU selinux_hide unavailable); that's a trade-off, not a mistake.
- Keep the stock image around to revert: `adb shell dd if=/dev/block/mmcblk0p33 of=/sdcard/boot_stock.img bs=4096`.
- First boot may take a bit; don't reboot right away.

Full changelog, build log and troubleshooting: docs/KERNELS.md; source on GitHub (link).
All GPL-2.0; thanks to the KernelSU team (tiann) — not affiliated with Xiaomi/Google.

Big thanks to the KernelSU + GKI-patch tooling communities!