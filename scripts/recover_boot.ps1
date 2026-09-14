$adb = "C:\Users\31806\Desktop\恢复\platform-tools\adb.exe"
$fb = "C:\Users\31806\Desktop\恢复\platform-tools\fastboot.exe"
$good = "C:\Users\31806\Documents\android-kernel\boot_backup_#27.img"
for ($i = 0; $i -lt 60; $i++) {
    $out = & $adb devices 2>&1 | Select-String "device$|\bfastboot\b"
    if ($out -match "fastboot") {
        Write-Output "FASTBOOT MODE detected"
        & $fb flash boot $good
        & $fb reboot
        Write-Output "FLASHED #27 + rebooted"
        exit 0
    }
    $dev = (& $adb devices 2>&1) -join "`n"
    if ($dev -match "device$") {
        Write-Output "ADB ONLINE - sending reboot bootloader"
        & $adb reboot bootloader 2>&1
        Start-Sleep 5
        for ($j = 0; $j -lt 30; $j++) {
            $out2 = & $adb devices 2>&1 | Select-String "fastboot"
            if ($out2) {
                Write-Output "FASTBOOT after adb"
                & $fb flash boot $good
                & $fb reboot
                Write-Output "FLASHED #27 + rebooted"
                exit 0
            }
            $fbdev = & $fb devices 2>&1
            if ($fbdev -match "fastboot") {
                Write-Output "FBDEV after adb"
                & $fb flash boot $good
                & $fb reboot
                Write-Output "FLASHED #27 + rebooted"
                exit 0
            }
            Start-Sleep 2
        }
    }
    Start-Sleep 2
}
Write-Output "NO WINDOW FOUND"