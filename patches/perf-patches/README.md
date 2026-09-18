# perf-patches

Performance / stability changes applied on top of the vendor MediaTek 4.19.275
tree (Redmi 9A / dandelion). These are context previews of the current tree —
no pristine vendor baseline is committed, so re-apply by editing the listed
files to match.

## Applied in kernels #61 / #62

| # | file | change |
|---|---|---|
| 0001 | `block/Kconfig.iosched` | add `DEFAULT_BFQ` choice option (olddefconfig-stable default) |
| 0002 | `fs/Kconfig` | add `config IO_URING` (the backport was missing its Kconfig switch) |
| 0003 | `mtk_ts_bts.c` | demote `wakeup_ta_algo` `pr_notice` -> `pr_debug` (noise) |
| 0004 | `mtk_ts_dctm.c` | demote `wakeup_ta_algo` `pr_notice` -> `pr_debug` (noise) |

## Not in this set

- **#62 TCP BBR** is a `.config`-level default (`CONFIG_TCP_CONG_BBR=y`,
  `CONFIG_DEFAULT_TCP_CONG="bbr"`), not a source patch — it lives in
  `scripts/build/`, not here.

## Related

- `../ksu43_kernelsu.patch` — the KernelSU v3.3.0 integration diff (separate concern).
- `modules/perftune/` — runtime tuning applied at boot (no rebuild).