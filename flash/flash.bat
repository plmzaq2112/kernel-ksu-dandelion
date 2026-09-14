@echo off
rem Flash boot_ksu43_load.img on Redmi 9A (dandelion, MT6765)
rem Requires: adb on PATH, unlocked bootloader, adb root working.
setlocal
set "IMG=%~dp0boot_ksu43_load.img"
set "BOOT_DEV=/dev/block/mmcblk0p33"

echo == push ==
adb push "%IMG%" /data/local/tmp/boot.img || goto :err

echo == verify boot partition (should print /dev/block/mmcblk0p33) ==
adb root
adb wait-for-device
adb shell readlink /dev/block/by-name/boot

echo WARNING: review the line above; flash target is %BOOT_DEV%
set /p go=Press Enter to flash or Ctrl+C to abort...

echo == flash ==
adb shell "dd if=/data/local/tmp/boot.img of=%BOOT_DEV% bs=4096 conv=fsync" || goto :err
echo == reboot ==
adb reboot
echo Done. Later verify: adb root & adb shell dmesg | grep -iE "Crowning|load_allow_uid|stage2"
goto :eof
:err
echo FAILED - check adb connection / image path.
exit /b 1