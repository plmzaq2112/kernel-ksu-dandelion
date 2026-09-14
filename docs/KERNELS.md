# 红米 9A (MT6765, dandelion) KernelSU 集成 — 最终说明（KSU#43）

设备：Redmi 9A (dandelion)，SoC MT6765，内核 4.19.275-mt6765，**boot 分区 `/dev/block/mmcblk0p33`**
编译：Ubuntu WSL (Ubuntu-26.04) + clang 18 (LLD)；permissive `androidboot.selinux=permissive`
镜像格式：boot.img (page_size=2048, header_version=2)

**最终成果：开机零手动持久化：Manager 自动 crown、授权列表自动加载、su 立即可用。UI 授权的软件重启后保留。**

## 当前设备状态（已刷 `boot_ksu43_load.img`，实测）

- 开机即 patch {setresuid, reboot}；开机 90s stage2 patch {execve, execveat, newfstatat, faccessat}（sucompat）
- **授权自动加载（本次修复）**：开机 `/data` 就绪后 `ksu_load_allow_list()` 主动执行（62s 实测：`load_allow_uid com.termux/bin.mt.plus/com.android.shell`），不再依赖 userspace 上报事件
- 30s 起 `track_throne` 每 30s 扫描 `/data/app` 找 Manager → v2 证书签名校验 → `Crowning manager`（62s 实测）
- 普通用户 shell `su -c id` → `uid=0(root)`；MT管理器等已授权软件开机直达 root
- **重要**：Manager 必须是 v2-only 重签名版 `KernelSU_v3.3.0_32601_gkipatched_v2only.apk`（含 v3 签名的 `gkipatched` 版会被 `is_manager_apk` 拒掉）

## 修复记录

- **#42 → #43（本次重大 bug 修复）**：*"重启后授权全掉"* 根因 = 授权列表从未加载回内核内存。
  KernelSU 加载 allowlist 依赖 userspace 通过 fd ioctl 上报 `REPORT_EVENT(EVENT_POST_FS_DATA)`，
  而 v3.3.0 Manager 集成模式从不发此事件 → 每次重启内核授权表恒空（文件 `/data/adb/ksu/.allowlist`
  始终完好）。修复：`manager/throne_tracker.c` 在 `track_throne()` 扫描成功后主动 `ksu_load_allow_list()`
  （static bool 保证只执行一次；幂等）。已修改文件收在 `final-kernel-patches/manager/throne_tracker.c`。
- #41 → **双参修复**：`ksu_direct_reboot_entry(int orig_nr, const struct pt_regs *regs)` 必须与
  `ksu_syscall_hook_fn` 类型一致；单参版在 `fn(nr, regs)` 调用时 x0 指向 nr → 野指针 panic（#39/#40 自重启根因）。

## 交付物（android-kernel 根目录）

| 内容 | 说明 |
|---|---|
| `boot_ksu43_load.img` | **正式版，已在设备运行**（含 allowlist 自动加载修复） |
| `boot_ksu38_dw.img` | 稳定基线（无 reboot 槽/无 load 修复），极端回退 |
| `boot_backup_#27.img` | stock 底镜像（#27 官方 release），还原原厂 |
| `boot-4.19.275-mt6765-ksu25[,-perm].img` | 构建脚本每次产出的最新构建（内容=当前 #43） |
| `final-kernel-patches/` | 7 个改动文件的最终快照 + README（含 #43 修复） |
| `wsl-scripts/build_ksu25_v2.sh` | 最终构建脚本（make → pack_boot.py → perm_cmdline.py） |
| `KernelSU_v3.3.0_32601_gkipatched_v2only.apk` | **必装 Manager**（重签名 v2-only） |
| `KernelSU_v3.3.0_32601_gkipatched.apk` | 对照版（v3 签名，开机不识别，仅参考） |
| `test_info` / `test_reboot`(+`.c`) | 回归测试件（/data/local/tmp/） |
| `execsu` | 汇编 su 活性测试 |
| `dump_ui.sh` / `parse_ui2.py` | UI 诊断 |
| `archive/` | 已被取代的镜像(#42 等)/脚本/日志/旧 APK（留存） |

## 重建/刷机速查

```bash
# 构建（WSL，增量；改内核源码后先同步 final-kernel-patches 再跑）
export PATH=/usr/lib/llvm-18/bin:$PATH
bash /mnt/c/Users/31806/Documents/android-kernel/wsl-scripts/build_ksu25_v2.sh   # 产出并 cp 到 Windows
# 刷入（Windows）
adb push boot_ksu43_load.img /data/local/tmp/boot.img
adb root
adb shell "dd if=/data/local/tmp/boot.img of=/dev/block/mmcblk0p33 bs=4096 conv=fsync"
adb reboot
# 验证（重启后 ~90s）
adb shell dmesg | grep -iE 'load_allow_uid|Crowning|stage2'
adb shell "id" && adb shell "su -c id"          # uid=0(root)
```

## 内核改动一览（详见 `final-kernel-patches/README.md`）

reboot 魔法槽（安装 fd）、crown（开机自动给 Manager fd）、sucompat（execve 重定向到 ksud）、
throne 自动持久化、**allowlist 自动加载（#43）**、90s stage2。全部源文件快照在 `final-kernel-patches/`，
与构建源码逐一 md5 一致。

## 历史

#22~27 早期 enforcing 路线 → #38 stage2 delayed 稳定基线 → #39/40 reboot 槽签名 bug（回退）→
#41 双参修复 + reboot 魔法通 → #42 开机自动 crown → **#43 allowlist 自动加载（最终版）**。

## 已清理的冗余（2026-09-13 优化）

- Windows `archive/`：30 个中间 boot 镜像（1.92GB）已删除
- WSL：`android_kernel_mt6765-main.zip`(217MB)、旧构建 `deepsix/out`(2.6GB)、
  APK 逆向目录/日志等 `deepsix` 残余（1.5GB）已删除
- 保留：源码树、`out_blossom`（增量编译目录）、`ramdisk_work`+`boot-4.19.275-full-v11.img`（重建依赖）、
  `KernelSU/` 官方 clone、`alioth19/`

> 授权持久化说明：KernelSU 授权写 `/data/adb/ksu/.allowlist`（二进制 v4）。重启丢失 = 内核未加载，
> 不是文件丢失；若再遇"授权全掉"，先 `adb shell dmesg | grep load_allow_uid` 确认加载。