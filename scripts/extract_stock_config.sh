#!/bin/bash
SRC=~/android-kernel/android_kernel_mt6765-main
cd "$SRC"
echo "=== extract real stock config from MIUI kernel Image ==="
scripts/extract-ikconfig /tmp/stock_Image > /tmp/stock_kernel.config 2>/tmp/ik.err
if [ $? -eq 0 ]; then
    echo "extracted OK, $(wc -l < /tmp/stock_kernel.config) lines"
    grep -E "^CONFIG_LOCALVERSION|^# CONFIG_LOCALVERSION|CONFIG_IKCONFIG|CONFIG_IKCONFIG_PROC" /tmp/stock_kernel.config
else
    echo "extract failed:"; cat /tmp/ik.err
fi
echo
echo "=== LCM / IMGSENSOR in REAL stock config ==="
grep -E "CONFIG_CUSTOM_KERNEL_LCM=|CONFIG_CUSTOM_KERNEL_IMGSENSOR=" /tmp/stock_kernel.config 2>/dev/null | head
echo
echo "=== blossom defconfig MTK core switches for comparison ==="
grep -E "CONFIG_WLAN_DRV_BUILD_IN|CONFIG_MTK_CONNSYS_DEDICATED_LOG_PATH|CONFIG_TRACE_PRINTK|CONFIG_MTK_COMBO=|CONFIG_MTK_COMBO_GPS|CONFIG_MTK_GPS_SUPPORT|CONFIG_MTK_COMBO_WIFI|CONFIG_MTK_BTIF|CONFIG_PREEMPT|CONFIG_MTK_CM_MGR|CONFIG_MTK_BOOT|CONFIG_MTK_LCM" arch/arm64/configs/blossom_defconfig /tmp/stock_kernel.config 2>/dev/null | head -40