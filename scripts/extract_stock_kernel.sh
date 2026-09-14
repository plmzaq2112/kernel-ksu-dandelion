#!/bin/bash
cd ~/android-kernel
echo "=== 1) build logs preserved ==="
ls -la /mnt/c/Users/31806/Documents/android-kernel/wsl-scripts/build*.log
echo
echo "=== 2) blossom_defconfig head (device-matched?) ==="
ls -la android_kernel_mt6765-main/arch/arm64/configs/
echo "--- blossom basic ---"
grep -E "^CONFIG_LOCALVERSION|CONFIG_MACH_MT|CONFIG_MTK_KERNEL|CONFIG_IKCONFIG|CONFIG_CUSTOM_KERNEL_LCM|CONFIG_CUSTOM_KERNEL_IMGSENSOR" android_kernel_mt6765-main/arch/arm64/configs/blossom_defconfig android_kernel_mt6765-main/arch/arm64/configs/stock_defconfig 2>/dev/null | head -40
echo
echo "=== 3) extract original kernel section from stock boot.img ==="
python3 - <<'PY'
import struct
d = open('stock_boot.img','rb').read()
page = struct.unpack_from('<I',d,36)[0]
ks = struct.unpack_from('<I',d,8)[0]
k = d[page:page+ks]
open('/tmp/stock_kernel','wb').write(k)
print('kernel len', len(k), 'first bytes', k[:4])
PY
file /tmp/stock_kernel
echo
echo "=== 4) decompress to Image ==="
if zcat /tmp/stock_kernel > /tmp/stock_Image 2>/dev/null; then echo "gzip ok, len=$(wc -c < /tmp/stock_Image)"; file /tmp/stock_Image; else echo "not plain gzip"; fi