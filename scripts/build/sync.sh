#!/bin/bash
cd /home/a12bbb/android-kernel/kernel-419/android_kernel_mt6765-main
export PATH=/usr/lib/llvm-18/bin:$PATH
# Keep KSU-critical symbols resolvable: KALLSYMS_ALL depends on DEBUG_KERNEL.
sed -i \
    -e 's/^# CONFIG_DEBUG_KERNEL is not set$/CONFIG_DEBUG_KERNEL=y/' \
    -e 's/^# CONFIG_KALLSYMS_ALL is not set$/CONFIG_KALLSYMS_ALL=y/' \
    /home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom/.config
make O=/home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom ARCH=arm64 CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- \
    LD=ld.lld NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip AR=llvm-ar \
    olddefconfig 2>&1 | tail -5
echo "=== check ==="
grep -nE 'STRICT_KERNEL_RWX|CC_VERSION_TEXT|CONFIG_GCC_VERSION|CONFIG_CLANG_VERSION|BUILD_ARM64_DTB|MTK_DTBO|KALLSYMS|DEBUG_KERNEL' /home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom/.config