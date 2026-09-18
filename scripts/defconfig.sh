#!/bin/bash
cd /home/a12bbb/android-kernel/kernel-419/android_kernel_mt6765-main
export PATH=/usr/lib/llvm-18/bin:$PATH
make O=/home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom ARCH=arm64 blossom_defconfig CC=clang CLANG_TRIPLE=aarch64-linux-gnu- 2>&1 | tail -10
