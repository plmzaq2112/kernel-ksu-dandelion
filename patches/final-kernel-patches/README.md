# KernelSU v3.3.0 (32601) — 最终补丁集

Redmi 9A / MT6765 / 4.19.275 permissive 内核集成 KernelSU 的自研改动。
本目录为**已应用后的最终源文件快照**，覆盖原文件即可复现，绝对路径：

`android_kernel_mt6765-main/drivers/kernelsu/<下面每行的相对路径>`

全部 6 个文件已与构建源码逐一 md5 校验一致（未做任何转换）。

| 文件 | 改动点 |
|---|---|
| `hook/arm64/syscall_hook.c` | stage1 补丁集 `nrs[] = { __NR_setresuid, __NR_reboot }`；stage2 `ksu_direct_patch_sucompat_syscalls()` 补丁集 `nrs[] = { __NR_execve, __NR_execveat, __NR_newfstatat, __NR_faccessat }`（90s 后由 worker 调用） |
| `hook/syscall_hook.h` | **`ksu_direct_reboot_entry` 声明为双参**：`long ksu_direct_reboot_entry(int orig_nr, const struct pt_regs *regs);`——必须与 `ksu_syscall_hook_fn` 类型（`long (*)(int, const struct pt_regs *)`）完全一致，否则会被当作 `(regs)` 调用、x0 指向 nr 野指针 → **panic/自重启**（#39/#40 根因） |
| `hook/syscall_hook_manager.c` | 注册 `__NR_setresuid`(getuid)、`__NR_reboot`(reboot slot)、`__NR_execve`、`__NR_execveat`、`__NR_newfstatat`、`__NR_faccessat`；`ksu_patch_sucompat_dw` 90s delayed work 调 stage2；`ksu_patch_sucompat_worker` 对 execve/faccessat 做 uid==1000 前置判断 |
| `supercall/supercall.c` | `ksu_direct_reboot_entry(int orig_nr, const struct pt_regs *regs)` 双参实现：校验 `PT_REGS_PARM1(regs) == 0xDEADBEEF && PT_REGS_PARM2(regs) == 0xCAFEBABE`，命中则 `task_work_add(current, &tw->cb, true)`（**4.19 老 API，第3参是 bool，无 TWA_RESUME 枚举**）并**返回 0，不调真实 reboot**（原复路会导致 MTK 内核实重启）；非 magic 时 `return ksu_syscall_table_orig[__NR_reboot](regs)` |
| `manager/throne_tracker.c` | 开机持久化：`ksu_throne_tracker_init` 调度 30s delayed work，`track_throne(false)` 扫描 `/data/app`（packages.list -> uid -> base.apk）找 Manager；失败每 30s 重试、最多 10 次，成功即自行停止。`is_manager_apk` 需**v2 证书签名**匹配（含 v3 签名的 APK 直接拒绝——`gkipatched.apk` 失败、`gkipatched_v2only.apk` 成功都因此） |
| `runtime/boot_event.c` | `on_boot_completed()` → `ksu_boot_completed=true` + `track_throne(false)`（已还原为 2 行） |

## 关键编译参数（构建时）
```
KSU_EXPECTED_SIZE=0x34c
KSU_EXPECTED_HASH=bbe8fc8d1e038c7f80865efbcd832ecc39da4a4228b4fb4d6e0a6750e9ddd7b8
KSU_MANAGER_PACKAGE=me.weishu.kernelsu
KCFLAGS="-Wno-error"
```

## 运行时行为（验证过的）
- 非 root shell 执行 `su`（KernelSU sucompat 重定向到 `/data/adb/ksud`）：allowlisted uid 提权至 root。
- Manager 从内核拿到 fd 后与 ksud socket 通信 -> UI 显示"工作中"；Manager 需安装 **v2only 版** APK。
- 开机 `Crowning manager: me.weishu.kernelsu(uid=10244)` 自动（30s 起，/data 挂载后）。
- `ksu_debug_manager_appid` 参数显示 `-1/4294967295` 为**正常**：它只是独立 debug 变量，真正 crown 存内核全局 `ksu_manager_appid`。