# ksu43_kernelsu.patch — KernelSU v3.3.0 → dandelion (MT6765 / 4.19.275)

One unified `git apply`-able patch covering the 7 changes made to adapt KernelSU
v3.3.0 to this non-GKI MediaTek 4.19.275 kernel. A copy of the resulting 7 files
in full is under `final-kernel-patches/` (straight copy-over, in case you prefer
that).

## What changed (see ../README.md Features for why)

1. **hook/arm64/syscall_hook.c** — pristine copy of the syscall table
   (`ksu_syscall_table_orig`) plus a direct slot patcher
   (`ksu_direct_syscall_entry` / `ksu_direct_patch_syscalls`) so hooks work on
   kernels without `CONFIG_FTRACE_SYSCALLS` (this MTK build has no syscall
   tracepoints). Stage1 (setresuid, reboot) is patched at init; stage2
   (execve, execveat, newfstatat, faccessat = sucompat) is deferred to 90s after
   boot because the exec detours panic during the early exec storm on this
   kernel.
2. **hook/syscall_hook_manager.c** — registers the reboot hook, guards the
   tracepoint registration on `CONFIG_FTRACE_SYSCALLS`, handles the 4.19
   `register_trace_sys_enter` API, and schedules the 90s delayed stage-2 patch.
3. **hook/syscall_hook.h** — new externs / prototypes.
4. **supercall/supercall.c** — kprobe-free fd-install path
   (`ksu_direct_reboot_entry`: the reboot magic number gets hijacked and turned
   into the fd-install task_work, the real reboot is never invoked for that
   sequence; upstream's kprobe path is kept behind `CONFIG_KPROBES`),
   `task_work_add(..., true)` replaces `TWA_RESUME` (absent on 4.19).
5. **manager/throne_tracker.c** — **allowlist auto-load**: `ksu_load_allow_list()`
   is called once `/data` is ready (first successful `packages.list` scan),
   because the v3 Manager never delivers the `post-fs-data` REPORT_EVENT on this
   GSI setup and upstream therefore loses every grant on reboot. Also: 30s x10
   Manager crown retries.
6. **runtime/boot_event.c** — boot_completed no longer force-crowns; the tracker
   loop owns that.
7. **core/init.c** — trigger one `track_throne(false)` probe right at late-init;
   `MODULE_IMPORT_NS` is gated to >= 5.4 (4.19 has no symbol namespaces).

## Applying

```bash
# from the root of a KernelSU v3.3.0 checkout where the kernel side lives in "kernel/"
# or the MTK tree where it lives in "drivers/kernelsu/" (same relative layout):
patch -p2 < ksu43_kernelsu.patch      # if your tree already has these files at kerneldir paths
git apply --reverse --check ksu43_kernelsu.patch   # shows it's a no-op on already-applied tree
```

The relative paths in the patch match both the upstream `kernel/<subdir>` layout
and the MTK `drivers/kernelsu/<subdir>` layout — pick `-p` accordingly
(`-p1` on MTK tree, `-p2` on upstream layout).

## Verifying identity (md5)

    md5sum 0dea413a core/init.c
    md5sum cd905a02 hook/syscall_hook.h
    md5sum 62c5ad88 hook/syscall_hook_manager.c
    md5sum 60b7d7ff hook/arm64/syscall_hook.c
    md5sum 7c40ee0a manager/throne_tracker.c
    md5sum 5c8548b2 supercall/supercall.c
    md5sum 3f63b9bc runtime/boot_event.c

## License

GPL-2.0 (see ../LICENSE). KernelSU itself is GPL-2.0 by its authors.