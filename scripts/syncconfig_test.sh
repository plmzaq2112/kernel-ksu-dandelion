#!/bin/bash
cd /home/a12bbb/android-kernel/kernel-upgrade/mtk50-port/out_blossom
echo "BEFORE syncconfig:"
grep -c BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES .config
/home/a12bbb/android-kernel/kernel-419/android_kernel_mt6765-main/scripts/kconfig/conf --syncconfig Kconfig < /dev/null > /dev/null 2>&1
echo "AFTER syncconfig (rc=$?):"
grep -n BUILD_ARM64_DTB_OVERLAY_IMAGE_NAMES .config