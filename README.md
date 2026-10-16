# KernelSU kernel for Redmi 9A (dandelion) — MT6765

A KernelSU-integrated kernel for the Redmi 9A / 9A Sport (dandelion), built on the
stock MediaTek MT6765 (Helio G25) kernel. KernelSU is compiled into the kernel, so
flashing the boot image is all it takes to get root — no kernel-flasher, no Magisk,
no per-boot setup.

- **Device:** Redmi 9A / 9A Sport — codename `dandelion` (MT6765 / Helio G25)
- **Kernel:** MediaTek stock 4.19 with KernelSU integrated (manual-hook, UAPI v5)
- **SELinux:** Enforcing
- **Manager:** official tiann KernelSU Manager — connects directly, no re-sign

## Features

- Root via `su` (uid 0), per-app allowlist and per-app profiles
- Kernel-level sucompat — the stock `su` binary is redirected to ksud
- Module support: `post-fs-data.sh` / `service.sh` run at boot
- No kprobes / no ftrace — hooks patch the syscall table directly

## Modules

KernelSU 3.x mounts a module's `system/` directory only if a **metamodule** is
installed. Without one, file-replacing modules are not applied — this is expected
behaviour, not a bug. Script-only modules work out of the box.

## Repository layout

| Path | Contents |
|---|---|
| `bakasu` (branch) | kernel source |
| `main` (branch) | docs, flash scripts, patches, modules, APK checksums |
| `flash/` | flash helpers (fastboot / adb-dd) |
| `apk/` | manager APK checksums |
| `scripts/` | build / pack / recover helpers |
| `modules/` | shipped KernelSU modules (e.g. perftune) |
| `patches/` | KernelSU + performance patches |
| `docs/` | build journal and reports |

## Downloads

Boot images, the manager APK and their SHA256 checksums are published on the
[Releases](https://github.com/plmzaq2112/kernel-ksu-dandelion/releases) page.

```
fastboot flash boot <boot-image>.img
fastboot reboot
```

## Credits / license

- [KernelSU](https://github.com/tiann/KernelSU) by tiann — GPL-2.0
- MediaTek kernel source — GPL-2.0
- Not affiliated with Xiaomi, Google, or KernelSU.
