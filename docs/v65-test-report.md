# v65 KernelSU 集成功能验收测试报告（只测试，不修改）

- **对象**：Redmi 9A (dandelion)，内核 `4.19.325-dandelion-ksu #7`（v65，BakaSU 手动 hook 线），管理器 BakaSU v3.3.1(32680-5)，`me.weishu.kernelsu`
- **环境**：设备 SN HU8DROH6BMHIEE99，adb 持续在线，SELinux 强制，测试窗口 2026-10-10 00:00–10:40（设备时间）
- **方法**：不改源码、不编译、不刷机；实机行为验证 + CLI/UI 双向交叉核对 + 4 次重启；自建最小无害测试模块（module.prop + 标记文件 + 两个只写 /data/local/tmp 标记的脚本）走完整模块生命周期后已完全清除，设备已还原
- **证据**：截图 6 张随附本目录（m2_su/m3_shell/m8_sel/m_reboot_home/mod_tab2/mod_disabled2）；CLI 输出见正文

## 一、测试矩阵执行结果

| 项 | 内容 | 结论 |
|---|---|---|
| T1.1 | 管理器识别内核 | **PASS** |
| T1.2 | 重启后管理器重连 | **PASS** |
| T1.3 | 内核↔管理器协议匹配 | **PASS** |
| T2.1 | 授权应用获取 root | **PASS** |
| T2.2 | 未授权调用被拒绝 | **PARTIAL**（见说明） |
| T2.3 | 撤销授权立即生效 | **PASS** |
| T2.4 | 授权重启持久 | **PASS**（4 次重启） |
| T3.1 | App Profile 配置面 | **PASS** |
| T3.2 | App Profile 行为生效 | **PASS** |
| T4.1 | 模块安装 | **PASS** |
| T4.2 | 模块重启激活 | **PASS** |
| T4.3 | 模块文件挂载（magic mount） | **初测 FAIL → 根因定位后修订 PASS**（见第六节） |
| T4.4 | 模块脚本执行 | **PASS** |
| T4.5 | 模块禁用/卸载 | **PASS** |
| T5.1 | SELinux 状态 | **PASS** |
| T5.2 | 普通应用/系统兼容 | **PARTIAL**（NFC ANR 循环，见说明） |
| T5.3 | 重启后 root 可用 | **PASS** |
| T5.4 | 内核日志健康 | **PASS** |

## 二、关键项明细

### T1 通信
- T1.1 操作：打开管理器首页；对照 `ksud debug version/info`、`uname`、`getenforce`。预期：全部一致显示工作中。实际：UI"工作中 / 35002-5 / 4.19.325-dandelion-ksu / SELinux 强制执行"，CLI `version=35002, uapi_version=5, features=0x5, runtime built-in`，完全一致。证据：截图 m_reboot_home.png。
- T1.2 操作：`adb reboot` 后启动管理器。实际：秒级重连，信息完整匹配。证据：m_reboot_home.png（第 2 次重启后采集，4 次重启行为一致）。
- T1.3 操作：全程抓 logcat。实际：无版本不匹配/通信错误；仅 1 条 10-09 历史 `ksud::cli` 报错（`/data/adb/modules` 尚不存在时执行 `module list` 的预期 ENOENT），环境无害。

### T2 SU 授权
- T2.1 操作：`su -c id`。实际：`uid=0(root) context=u:r:ksu:s0`；能读 /data/data 受保护数据、管理 440 个 root 进程。PASS。
- T2.3 操作：管理器 UI 关闭 Shell 超级用户开关 → `su -c id` → 重新开启 → 再测。预期：撤销后拒绝、重授权后恢复。实际：撤销后 `/system/bin/su` 兼容二进制被移除，`su -c id` → rc=127 无 root；重授权后 su 立即恢复（330744 字节），`uid=0 rc=0`。完整闭环，证据截图 m2_su.png（列表 ROOT 角标）。
- T2.2 判 **PARTIAL**：撤销后 uid 2000 已无法获得 root（行为结果成立）；但"从未授权 uid 直接调 su 被内核拒绝"的内核判定路径无直接证据——设备无 setpriv（toybox 无）、无可调试 run-as 目标、无 busybox，无法构造降权调用。撤销路径的行为拒绝已验证，内核拒绝路径未直接观察。
- T2.4 操作：4 次重启后重复 `su -c id`。实际：每次 uid=0 正常，allowlist 持久。PASS。

### T3 App Profile
- T3.1 实际：UI 字段全集 = UID/GID/组/权能/挂载命名空间/标签(NO_NEW_PRIVS)/SELinux(u:r:ksu:s0)，档位 默认/模板/自定义；与 dmesg `set root profile, key: com.android.shell, uid:2000, gid:0, context:u:r:ksu:s0` 及实际 su 会话 `gid=0, context=u:r:ksu:s0` 一致。证据：m3_shell.png。
- T3.2 操作：将 Shell profile"组"None→shell（gid 2000）→ 新开 `su -c id` → 还原 None → 再测。预期：profile 改动反映到新 su 会话。实际：`groups=0(root)` → `groups=0(root),2000(shell)` → 还原后恢复 `groups=0(root)`，**无需重启即时生效**。证据：m8_sel.png。PASS。

### T4 模块（自建最小无害模块 ksu_accept_test，测毕已完全清除）
- T4.1 `ksud module install` rc=0，staging 结构正确，list 与管理器模块页 UI 一致（mod_tab2.png）。
- T4.2 重启后 `update:false, enabled:true`，激活完成。
- T4.3 **初测 FAIL**：`system/etc/ksu_accept_marker.txt` 在 4 次重启、shell/root/`su -M`（全局挂载命名空间）三种视角下均不存在；`mount` 表零 modules 条目；开机日志 PostFsData 阶段（10:14:43）从 feature init 到 post-mount.d 仅 3ms、无任何挂载动作。**【验收后修订】**初判"挂载不生效且静默"不完整——实为 KernelSU 3.x 架构设计：未安装 metamodule 时 system/ 目录不挂载属预期行为，非内核/ksud 缺陷。三版本对比、根因与解决过程见第六节；装入 Hybrid Mount 后复测 **PASS**。
- T4.4 PASS：post-fs-data.sh 于 10:27:03、service.sh 于 10:27:05 在正确启动阶段执行（644 权限下由 sh 解释执行）；禁用后重启，两脚本标记均未再生成。
- T4.5 PASS：`disable` → `enabled:false` + UI 开关一致（杀进程刷新后；同会话存在列表缓存不刷新的小观察项，mod_disabled2.png）；`uninstall` → `remove:true` 标记 → 重启后模块目录完全清除，list 恢复 `[]`，root 不受影响。

### T5 系统兼容
- T5.1 `getenforce=Enforcing`；全程 dmesg `avc:` 计数 0。PASS。
- T5.2 判 **PARTIAL**：整机可用（桌面/设置/adb/管理器正常）。发现持续异常：`com.android.nfc` 每约 90 秒一次启动 ANR（长 uptime 时累计 134 次，为系统唯一 ANR 源）。根因链完整：内核 `# CONFIG_NFC is not set` + DTS 关闭 NFC 节点（v64 报告已记录的预期配置，Redmi 9A 无 NFC 硬件）→ `/dev/nfc*` 不存在 → NFC HAL 无法注册（hwservicemanager `ctl.interface_start` 失败）→ NfcService 主线程永久等待 HIDL → ANR。ANR 堆栈无任何 KSU 帧、dmesg 无 ksu/nfc 交互 → **与 KernelSU hook 无直接关联**；但"刷 v64/v63 等历史版本是否同样存在"未复测（超出只测当前版约束），该归因含此推测成分。
- T5.3 4 次重启后 root 均可用。PASS。
- T5.4 dmesg 无真实 panic/oops/BUG（`panic|oops|BUG:` 的 9 条命中经逐条核对均为 ramoops 参数与 `*-debug:` 设备名的子串误报）；仅充电相关 `get_ibus failed -524`/`ALG_INIT_FAIL`，与 KSU 无关。PASS。

## 三、验收四问回答（只报实际结果）

> **说明**：以下为**验收当时**的四问回答（T4.3 记为 FAIL）。经第五节跨版本对比 + 第六节根因定位，T4.3 定性为"KernelSU 3.x 设计前提（需装 metamodule），非缺陷"并复测 PASS；**修订后的四问见第七节**。此处保留原文以记录结论演进全过程。

**1）已验证的核心功能？**
内核-管理器通信与重启重连；SU root 获取（uid=0 + ksu:s0 上下文）；授权管理完整闭环（撤销→无 root，重授权→恢复）；授权 4 次重启持久；App Profile 配置→行为即时生效与还原；模块安装/重启激活/双阶段脚本执行/禁用生效/卸载完全清除；SELinux 强制且无新增 avc；内核无 panic/oops。

**2）缺证据（或结论为负）的功能？**
- 未授权 uid 直接调 su 的内核拒绝路径（无降权工具，标 PARTIAL）；
- **模块 system/ 文件挂载：实测失效（FAIL），且失效静默无任何报错**；
- sulog/adb_root/selinux_hide（当前 DISABLED，无行为可测）；
- 多用户/工作资料、在线更新等未覆盖场景；
- 长期稳定性仅有约 1.5 小时 × 4 次重启的短期证据。

**3）能否称"核心 Root 功能完整"？**
**授权/SU/Profile 核心链路：可以称完整**（全行为证据）。**整体"Root 功能完整"：不能**——模块挂载子系统失效，依赖文件替换的模块（字体、Xposed 类、系统修改类）在本内核上静默无效。准确表述为：**核心 Root 授权链路完整；模块功能仅脚本部分完整，文件挂载部分失效。**

**4）有无"功能完整且稳定"的证据？**
**不能作此表述。** 稳定性侧证据充分（4 次重启 root 稳定、无 panic/oops、无 avc、管理器每次正常重连）；但"完整"侧被 T4.3 FAIL 否定。可辩护的最大结论：**"核心 Root 授权链路功能完整且重启稳定；模块文件挂载功能在本内核线失效（静默），属未在历史版本测过的既有能力边界还是新回归，本次未验证（需刷机对比，超出约束）。"**

## 四、测试边界
- 全部结论基于 v65 实机行为，无源码修改、无编译、无刷机（后续第六节对比验证经用户同意执行了历史版本刷机对比）；
- T2.2 内核拒绝路径、T5.2 历史版本对比两项为明确的证据缺口，未以任何推定填补；
- 测试模块及全部临时文件已从设备清除，Shell 授权/Profile 均已还原基线（最终设备状态见第六节）。

## 五、追加对比验证（v63 / v64 / v65 同题复测）

针对 T4.3 挂载失效，刷入历史版本各装同一最小测试模块（脚本 + system/ 标记文件）做同题验证：

| 版本 | 内核 | ksud | 模块脚本执行 | system/ 文件挂载 |
|---|---|---|---|---|
| v63 | 4.19.275-v11ksu #1 | 32601 | ✓（post-fs-data + service 双阶段） | ✗ |
| v64 | 4.19.325-dandelion-ksu #6 | 32680 | ✓ | ✗ |
| v65 | 4.19.325-dandelion-ksu #7 | 35002 | ✓ | ✗ |

镜像均自 GitHub release 下载并校验侧车 SHA256（v64 `26446154…`、v63 `f5ec15bd…`、v65 `580575ce…` 匹配）。v63 上 su 激活按其血统注意事项装 v2-only 管理器（SHA256 `fea71139…` 与台账一致）完成。结论：**挂载失效并非 v64/v65 换代引入的回归，v63 同样如此**——排除"新线引入"假设，指向架构性原因。测毕已刷回 v65 并还原 BakaSU v3.3.1 管理器。

## 六、根因定位与解决（T4.3 修订）

**定性结论：本来就这样（by design），非 bug。** 三源互证：① 上游提交 PR #2929 标题即 "support metamodule, remove built-in overlayfs mount"，系刻意、有记录的架构改动；② 官方文档明确 "Mounting requires a metamodule"；③ v63/v64/v65 跨版本、跨内核线行为完全一致（脚本执行、文件不挂载、静默无报错）——真 bug 不会如此整齐。内核源码无挂载实现、ksud 有完整 metamodule 执行链，均与之吻合。

**版本时间线（解释"为何初判像 bug"）**：3.x 之前 KernelSU 内置 overlayfs，模块 system/ **开箱自动挂载**；3.x（PR #2929）把挂载改为外挂 metamodule，**不装则静默不挂**。故"KernelSU 应能直接挂模块"的预期对老版本成立，3.x 起不再成立。本内核未坏、KernelSU 未坏；默认安装不带挂载引擎且不装时无任何报错——这一静默体验是合理 UX 批评点，正是本次验收初判 FAIL 的成因。

**与挂载无关的两点澄清**：换 kprobes 或换 GKI 内核**均不改变**此结论——要求挂载须有 metamodule 的逻辑住在所有内核线共享的 ksud（用户空间），与内核如何安装 hook（kprobes / manual hook）、是否 GKI 无关。

**根因（源码 + 官方文档 + 二进制 strings 三方互证）**：KernelSU 3.x（上游 PR #2929 "support metamodule, remove built-in overlayfs mount"）把模块文件挂载从内核/ksud 内置实现中移除，改为**必须安装 metamodule（元模块）提供挂载引擎**。官方文档原文："Without a metamodule installed, modules will NOT be mounted."。本设备三版本均未装任何 metamodule → system/ 不挂载是**设计预期，非缺陷**：
- 内核侧：`drivers/kernelsu/` 无任何文件重定向/挂载实现，仅有 `EVENT_MODULE_MOUNTED` 通知接口（供引擎回报）与 kernel_umount 门控（`ksu_module_mounted`）；`CONFIG` 无挂载选项；
- ksud 侧：strings 含 `ksud::metamodule`、`ksud::magic`、`metamount.sh` 执行链、`/data/adb/metamodule/` 专用路径与 symlink 机制；
- 设备侧：PostFsData 阶段无挂载动作即因无 metamodule 可执行。

**解决**：安装官方模块仓库唯一在列 Metamodule **Hybrid Mount v6.2.3**（`github.com/Hybrid-Mount/meta-hybrid_mount`，1.7k stars，metamodule=1，OverlayFS 模式，内核 `CONFIG_OVERLAY_FS=y` 兼容）。metamount.sh 链路：`hybrid-mount boot` → `ksud kernel notify-module-mounted` → 内核 `on_module_mounted!`。

**解决后复测（连续 2 次重启均 PASS）**：
- `/system/etc/ksu_accept_marker.txt` 真实挂载，内容可读（shell/root 双视角）；
- mount 表：`KSU on /system/etc type overlay (...,lowerdir=.../ksu_accept_test/system/etc:/system/etc)`，source=KSU 合规；
- 日志链：`ksud::metamodule: Found metamodule… → Executing mount script` → `HybridMount: plan overlay_ops=1` → 内核 `[7.461031] KernelSU: on_module_mounted!`；
- 引擎状态实时显示 `OverlayFS: 1`；模块脚本照常执行；root/授权不受影响。

**修订后的 T4.3 结论：PASS（前提：安装 metamodule）**。未装 metamodule 时 system/ 不挂载 = 预期行为，属使用前提而非功能缺陷；但该前提对用户是隐性的，值得在发行说明中提示（见第七节建议）。

## 七、修订后的四问结论

1. **已验证核心功能**：通信/重启重连、SU root、授权撤销-恢复-持久、Profile 即时生效、模块安装/激活/脚本双阶段/禁用/卸载、**模块文件挂载（装 metamodule 后，2 次重启验证）**、SELinux 强制、无 panic/oops。
2. **缺证据**：未授权 uid 直调 su 的内核拒绝路径（无降权工具）；挂载功能仅 2 次重启的短期稳定性证据；T5.2 历史版本 NFC 对比未测。
3. **能否称"核心 Root 功能完整"**：**可以**——授权/SU/Profile/模块脚本/模块文件挂载（满足官方设计前提 metamodule 时）全部有行为证据。表述须带前提："核心 Root 功能完整（模块 system/ 文件挂载需安装 metamodule，为 KernelSU 3.x 设计前提）"。
4. **有无"功能完整且稳定"的证据**：功能完整性证据已齐（初测 FAIL 已定根因并解决）；稳定性证据仍为短期（root 授权 4 次重启 + 挂载 2 次重启）。**可称"功能完整，短期重启稳定"；长期稳定性（多日挂机）未验证，不作断言。**

**给发行说明的建议（待用户决定是否写入）**：
> 注意事项：KernelSU 3.x 需安装 metamodule（如 Hybrid Mount / meta-overlayfs）才能挂载模块的 system/ 目录；仅依赖开机脚本的模块无需安装。未安装时 system/ 文件不生效属预期，非内核问题。
