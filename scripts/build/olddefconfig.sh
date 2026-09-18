#!/bin/bash
cd /home/a12bbb/android-kernel/kernel-419/android_kernel_mt6765-main
export PATH=/usr/lib/llvm-18/bin:$PATH
export WSLENV=
make O=/home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom olddefconfig KCFLAGS=-Wno-error 2>&1 | tail -8