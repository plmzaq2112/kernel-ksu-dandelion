#!/bin/bash
set -e
OSRC=/home/a12bbb/android-kernel
W=$OSRC/ramdisk_work
O=$OSRC/out_blossom
export PATH=/usr/lib/llvm-18/bin:$PATH
PACK=/mnt/c/Users/31806/Documents/android-kernel/wsl-scripts/pack_boot.py
PERM=/mnt/c/Users/31806/Documents/android-kernel/wsl-scripts/perm_cmdline.py
WOUT=/mnt/c/Users/31806/Documents/android-kernel

make -C $OSRC/android_kernel_mt6765-main O=$O ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- \
    LD=ld.lld NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip AR=llvm-ar \
    KCFLAGS="-Wno-error" \
    KSU_EXPECTED_SIZE=0x34c \
    KSU_EXPECTED_HASH=bbe8fc8d1e038c7f80865efbcd832ecc39da4a4228b4fb4d6e0a6750e9ddd7b8 \
    KSU_MANAGER_PACKAGE=me.weishu.kernelsu \
    -j$(nproc) Image.gz > $OSRC/build_ksu25_v2.log 2>&1
echo "RC=$?"
grep -E "^ERROR|^error:|undefined reference|fatal" $OSRC/build_ksu25_v2.log | grep -v '^$' | sort -u | head -20
grep -iE "KernelSU (version|Manager)" $OSRC/build_ksu25_v2.log | head
strings $O/vmlinux | grep -m1 'Linux version 4\.'

if [ -f $O/arch/arm64/boot/Image.gz ]; then
  export KERNEL_IMG=$O/arch/arm64/boot/Image.gz
  export RAMDISK_IMG=$W/v11_clean1-rd.gz
  python3 $PACK $OSRC/boot-4.19.275-full-v11.img $OSRC/boot-4.19.275-mt6765-ksu25.img
  python3 $PERM $OSRC/boot-4.19.275-mt6765-ksu25.img $OSRC/boot-4.19.275-mt6765-ksu25-perm.img
  cp $OSRC/boot-4.19.275-mt6765-ksu25.img        $WOUT/
  cp $OSRC/boot-4.19.275-mt6765-ksu25-perm.img   $WOUT/
  echo "== ksu25 v2 (+perm) packed =="
else
  echo "== Image.gz not produced =="
fi