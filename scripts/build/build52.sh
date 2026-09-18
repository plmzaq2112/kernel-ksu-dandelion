#!/bin/bash
set -e
SRC=/home/a12bbb/android-kernel/kernel-419/android_kernel_mt6765-main
export PATH=/usr/lib/llvm-18/bin:$PATH
make -C $SRC O=/home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom ARCH=arm64 CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- \
    LD=ld.lld NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip AR=llvm-ar \
    KCFLAGS="-Wno-error" \
    KSU_EXPECTED_SIZE=0x34c \
    KSU_EXPECTED_HASH=bbe8fc8d1e038c7f80865efbcd832ecc39da4a4228b4fb4d6e0a6750e9ddd7b8 \
    KSU_MANAGER_PACKAGE=me.weishu.kernelsu \
    -j$(nproc) Image.gz > /home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/build_ksu52.log 2>&1
echo "RC=$?"
grep -E "^ERROR|^error:|undefined reference|fatal" /home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/build_ksu52.log | grep -v '^$' | sort -u | head -20
echo "--- tail ---"
tail -20 /home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/build_ksu52.log
strings /home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom/vmlinux | grep -m1 'Linux version 4\.'
ls -la /home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom/arch/arm64/boot/Image.gz