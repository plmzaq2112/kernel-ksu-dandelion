Perf-patches: performance / stability changes applied on top of the
vendor MediaTek 4.19.275 tree (Redmi 9A / dandelion).

Applied in kernels #61/#62:
  0001  block/Kconfig.iosched : add DEFAULT_BFQ choice option (olddefconfig-stable)
  0002  fs/Kconfig            : add config IO_URING (backport was missing the switch)
  0003  mtk_ts_bts.c          : demote wakeup_ta_algo pr_notice -> pr_debug
  0004  mtk_ts_dctm.c         : demote wakeup_ta_algo pr_notice -> pr_debug

Note: these are context previews of the current tree (no pristine vendor
baseline committed). Re-apply by editing the listed files to match.
