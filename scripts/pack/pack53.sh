#!/bin/bash
set -e
OSRC=/home/a12bbb/android-kernel/kernel-upgrade/mtk50-port
O=$OSRC/out_blossom
W=$OSRC/ramdisk_work
export PATH=/usr/lib/llvm-18/bin:$PATH
PACK=/home/a12bbb/android-kernel/kernelsu/release/scripts/pack_boot.py
PERM=/home/a12bbb/android-kernel/kernelsu/release/scripts/perm_cmdline.py
WOUT=/mnt/c/Users/31806/Documents/android-kernel
export KERNEL_IMG=$O/arch/arm64/boot/Image.gz
export RAMDISK_IMG=$W/v11_clean1-rd.gz
python3 $PACK $OSRC/boot-4.19.275-full-v11.img $OSRC/boot-4.19.275-mt6765-ksu53.img
python3 $PERM $OSRC/boot-4.19.275-mt6765-ksu53.img $OSRC/boot-4.19.275-mt6765-ksu53-perm.img
cp $OSRC/boot-4.19.275-mt6765-ksu53.img        $WOUT/
cp $OSRC/boot-4.19.275-mt6765-ksu53-perm.img   $WOUT/
ls -la $WOUT/boot-4.19.275-mt6765-ksu53*.img
echo "== ksu53 packed =="