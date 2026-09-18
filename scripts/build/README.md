# scripts/build — kernel build & config

Build and Kconfig tooling for the dandelion 4.19.275 tree (Ubuntu clang/LLD 18).

## Current flow (kernel #62)

```
bash scripts/build/sync.sh             # inject DEBUG_KERNEL + KALLSYMS_ALL, run olddefconfig
bash scripts/build/build53.sh          # make Image.gz -> out_blossom/arch/arm64/boot/Image.gz
bash scripts/pack/pack53.sh            # pack boot image (see ../pack/README.md)
```

Then flash the produced `boot-4.19.275-mt6765-ksu53-perm.img`.

## Scripts

| script | purpose | status |
|---|---|---|
| `build53.sh` | build current #62 kernel (io_uring/BFQ/KSM/THP/HZ1000/BBR) | active |
| `sync.sh` | enable DEBUG_KERNEL + KALLSYMS_ALL in .config, run olddefconfig | active |
| `defconfig.sh` | run `blossom_defconfig` | active |
| `olddefconfig.sh` | normalize .config against Kconfig | active |
| `syncconfig_test.sh` | verify DTB overlay config survives `--syncconfig` | dev-only |
| `build52.sh` | pre-#61 build, kept for reference | historical |
| `build_ksu25_v2.sh` | KSU#25-era build, kept for reference | historical |

> Paths inside scripts are machine-specific (see ../README.md); adjust `SRC`/`O`
> to your own checkout before running.