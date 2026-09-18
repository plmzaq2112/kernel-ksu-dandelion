# scripts/pack — boot image packing tools

Genericized MTK boot-image tools extracted during reverse-engineering. Used to
swap the kernel inside a stock boot image while keeping ramdisk/dtb (page_size
2048, header v2) intact, then re-pack with an adjusted cmdline.

| tool | purpose |
|---|---|
| `pack53.sh` | current #62 flow: build Image.gz -> boot-4.19.275-mt6765-ksu53-perm.img |
| `pack52.sh` | pre-#61 packing, kept for reference |
| `pack_boot.py` | pack a boot image from a stock image (kernel replaced, header v1/v2) |
| `perm_cmdline.py` | append `androidboot.selinux=permissive` to the boot cmdline |
| `inspect_bootimg.py` | print boot image header fields from a stock image |
| `make_imagelz4.py` | wrap a raw Image into a legacy LZ4 stream (unused by current flow) |
| `verify_bootimg.py` | sanity-check kernel_size/ramdisk_size fields of a packed image |