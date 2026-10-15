# 内核态 magic mount 评估与风险报告

- 日期：2026-10-15
- 目标内核：dandelion/Redmi 9A，MT6765，Linux 4.19.325，KPROBES=n
- 集成线：BakaSU manual-hook（`CONFIG_KSU_MANUAL_HOOK=y`），仓库 `kernel-ksu-dandelion`
- 触发背景：v65 验收 T4.3（模块 system/ 文件挂载）初判 FAIL，经 v63/v64/v65 三版本对比 + 根因定位，确认为 KernelSU 3.x 设计前提（需装 metamodule），非内核缺陷。用户提出"能否把挂载做进内核"，并选定方向 **A：内核态文件重定向**，要求先出本评估。

---

## 0. 概念澄清：overlayfs 已经是"内核态"的

这是评估 A 前必须先对齐的事实，否则会基于错误前提决策。

- 当前 Hybrid Mount 方案中，`metamount.sh` 只在 post-fs-data 阶段执行一次 `hybrid-mount boot`，**发起** `mount -t overlay KSU /system/etc`。
- 之后每一次对 `/system/etc/...` 的实际访问（open/stat/getdents/...），路径重定向**全部由内核的 `fs/overlayfs/` 代码完成**，用户空间不再参与任何一次访问。
- 证据：v65 复测 mount 表 `KSU on /system/etc type overlay (lowerdir=.../ksu_accept_test/system/etc:/system/etc)`；内核 `CONFIG_OVERLAY_FS=y`；内核侧仅有 `on_module_mounted()` 回调 + `ksu_module_mounted` 标志（用于 umount 门控），**无任何文件重定向实现**——因为重定向本就该由内核 overlayfs 承担，KernelSU 内核侧从不需要自己做。

**结论：把重定向逻辑"做进内核"已经是现状。** 方案 A 的真实定义不是"从用户空间搬进内核"，而是：

> **放弃内核现成的 overlayfs 实现，改用 syscall/VFS 拦截，在 KernelSU 自己的代码里从零重写一套文件重定向。**

---

## 1. 方案 A 的真实工作量分解

要在内核侧（不经 mount namespace/overlayfs）让 `/system/etc/foo` 透明指向 `/data/adb/modules/<id>/system/etc/foo`，必须覆盖下列全部面。

### 1.1 需拦截的 syscall 面（不完整即漏、即崩）
| 类别 | syscall | 备注 |
|---|---|---|
| 打开 | openat, openat2, creat | 主路径 |
| 元数据 | statx, newfstatat, fstatat64, fstat, lstat, stat | 已有 su 用 stat 钩子可复用框架 |
| 存在性 | access, faccessat, faccessat2 | 已有 faccessat 钩子 |
| 列目录 | getdents, getdents64 | **最难点**，见 1.2 |
| 执行 | execve, execveat | 内核 exec 路径 |
| 读链接 | readlink, readlinkat | |
| 其他 | fchmodat, utimensat, copy_file_range, ioctl(FS_IOC_*)... | 易漏 |

漏掉任何一个 → 该操作读到真实 `/system` 而非模块文件 → 部分生效/不一致。

### 1.2 目录合并（getdents）——最大的坑
overlayfs 天然给出"真实目录 ∪ 模块目录"的合并视图 + 白目录（删除）+ opaque 目录。用 syscall 拦截重做：
- 需在 `getdents64` 返回后**合成合并条目**（真实条目 + 模块独有条目），并**剔除被模块覆盖的真实条目**；
- 需要一套白目录约定实现"删除系统文件"；
- 性能上每次列目录都要遍历所有相关模块目录；极易出现 dirent 缓冲区越界、`d_off` 断裂、迭代器重入崩溃。

### 1.3 SELinux 标签
- 模块文件物理在 `/data`（`u:object_r:system_file:s0` 之外的标签）；重定向访问时必须**在内核里动态改写 inode 安全标签**，否则 system_server/linker 访问即 `avc: denied` → 开机即崩。
- overlayfs 用 workdir/上下文继承解决了这件事；自研需手写，且要覆盖 `getxattr/ security.selinux`、`inode_init_security`、`may_open` 等多点。

### 1.4 全局性能税
- 每一次全系统范围的 stat/open 都要过一次 KSU 钩子 + 路径改写判断。overlayfs 是 VFS 层内联、几乎零成本；syscall 拦截是每次进入/退出内核都要比对。
- 对 MT6765 这类中低端 SoC，开机 + 应用冷启的 I/O 热路径上是实打实的退化。

### 1.5 无法覆盖的内核内部路径
- syscall 拦截只覆盖"从用户态进来的 syscall"。bionic linker、`system_server`、内核线程通过 `filp_open()` 等**内核内部**打开文件的路径**不会经过 syscall 表** → 拦不到 → 这些读取看到真实文件，产生不一致。

---

## 2. 现有可复用基础设施盘点（客观有利项）

| 组件 | 位置 | 复用价值 |
|---|---|---|
| syscall 表 hook 框架 | `hook/arm64/syscall_hook.c` + `syscall_hook_manager.c` + `patch_memory.c` | 高：架构无关 dispatcher，可 `ksu_register_syscall_hook(nr, fn)` 注册任意 syscall |
| 直接 syscall 表 patch | `ksu_syscall_table_hook(nr, fn, &orig)` | 高：已在用（execve/read/fstat） |
| LSM hook 修补框架 | `hook/lsm_hook_magic.c`（474 行）+ `lsm_hooks.c` | 高：可 patch `security_hook_heads`/`selinux_ops` 槽位挂 `file_permission`/`inode_*` |
| stat/open 手动 hook 补丁 | `patches/0011(faccessat)`, `0012(stat)` | 中：文件访问路径的接入点已在源码里 |
| kernel_umount 特性 | `feature/kernel_umount.c` + `ksu_module_mounted` 门控 | 中：内核已有"模块已挂载"状态机 |

**判断：做 A 的地基齐全，这不是"能不能搭起来"的问题，而是"搭起来后正确性/性能/可维护性"的问题。**

---

## 3. 风险登记册

| # | 风险 | 严重度 | 说明 |
|---|---|---|---|
| R1 | 内核 panic / 开机即崩 | 高 | VFS 钩子在遍历/锁上下文运行，缓冲区与锁错误直接 panic，且发生在最热路径 |
| R2 | SELinux 拒绝导致系统服务起不来 | 高 | 标签改写漏一处 → system_server/linker 访问 /system 失败 → bootloop |
| R3 | 覆盖面永远差一点 | 高 | syscall 面 + 内核内部 filp_open 无法全覆盖，长期"部分生效" |
| R4 | 与 manual-hook 架构冲突 | 中 | 本线已是 KPROBES=n 的手动 patch，再叠加一层 VFS 拦截，patch 面积↑、与上游 diff 巨大 |
| R5 | 每次内核 bump 都要重维护 | 中 | 上游 4.19.x 小版本改动 `fs/` 结构即需重对补丁 |
| R6 | 逆上游设计 | 中 | 上游 3.x 正是**因为**这类方案脆弱才删掉内置挂载、改用 overlayfs（PR #2929） |
| R7 | 性能退化可测量 | 中 | 中低端 SoC I/O 热路径全局税 |

**注意：SUSFS 不是 A 的替代品。** Kconfig 里的 `KSU_SUSFS_SUS_MOUNT` 是"隐藏已存在的可疑挂载条目"，它**不做挂载**，只做隐藏，且方向是规避检测而非模块功能。评估中出现它只是为了说明：若动机是"隐匿"，SUSFS 更对口；若动机是"模块功能"，SUSFS 无关。且本内核树 `fs/susfs.c` / `include/linux/susfs.h` 均不存在，启用 `CONFIG_KSU_SUSFS` 会触发 Kbuild `$(error)`（`drivers/kernelsu/tools/susfs_compat.mk` 末行硬报错）——SUSFS 集成本身也是独立的移植工程。

---

## 4. 方案 A vs 现行 overlayfs 逐项对比

| 维度 | A（自研内核拦截） | 现行 overlayfs（metamodule） |
|---|---|---|
| 重定向位置 | KSU 自研代码（syscall/VFS 拦截） | 内核 `fs/overlayfs/` |
| 目录合并/白目录 | 需从零实现，易错 | 内核现成、久经考验 |
| SELinux | 需手写改写，高危 | overlayfs 原生处理 |
| 性能 | 每次访问全局税 | VFS 内联，近零成本 |
| 内核内部路径 | 覆盖不到 | 天然覆盖（走 VFS） |
| mount 表可见性 | 可做到无条目（隐匿） | 有 `KSU on /system` 条目（可检测） |
| 工程量 | 大（数周级，含调试） | 已完成（装个模块） |
| 崩溃/维护风险 | 高 | 低 |
| 与上游一致性 | 逆流 | 顺流 |

**唯一 A 占优的维度是"mount 表隐匿"。** 若用户目标是让模块功能可用 → overlayfs 全面占优；若目标是"不留 mount 痕迹规避检测" → A 才有意义（但那更该用 SUSFS 隐藏，而非重写挂载）。

---

## 5. 若坚持 A 的分阶段降险计划（供决策，非建议执行）

- **Phase 0 — 可行性尖刺（必做）**：只实现 `newfstatat` 单一 syscall 对**单个文件**的重定向（无 getdents、无白目录），验证"手动 hook + 路径改写 + SELinux 标签"三件套能在 MT6765 上稳定跑通且不崩。**产出 go/no-go。**
- **Phase 1**：补 openat/access/execve，做只读文件级重定向（不含目录合并）。
- **Phase 2**：getdents64 目录合并 + 白目录（工程量翻倍、风险最高的一步）。
- **Phase 3**：全量 syscall 面 + 性能基线对比 + 72h 稳定性挂机。
- 任一 Phase 出现 R1/R2 即止损。

即便走完，得到的是"无 mount 条目"这一收益，代价是持续维护 + 全局性能税。

---

## 6. 结论与建议

1. **A 技术上可做**（地基齐全），但**它解决的唯一实际收益是 mount 表隐匿**，而非"让模块挂载可用"——后者现行 overlayfs 已可用且已通过 v65 复测（2 次重启 PASS）。
2. **A 不是"把功能搬进内核"**，因为重定向本就在内核（overlayfs）；A 是"用自研拦截替换内核 overlayfs"，属逆上游、高风险、大维护。
3. **建议**：
   - 若目标是**模块文件挂载功能**：不要 A，采用现行 overlayfs，仅需决定是否把 metamodule 打进镜像自动预装（方向 B）以实现开箱即用。
   - 若目标是**隐匿 mount 条目**：优先评估 **SUSFS**（`KSU_SUSFS_SUS_MOUNT`），而非重写挂载；但 SUSFS 集成本身是独立移植工程（当前树缺失 susfs 源码）。
   - **A 仅在"明确要隐匿 + 接受大维护 + 有 Phase 0 go/no-go 把关"时才值得启动。**

本报告不改变 v65 现状：设备仍 v65 + BakaSU + Hybrid Mount，模块文件挂载工作正常。是否启动 A 的 Phase 0，待用户决定。
