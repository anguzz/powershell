$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.WAU.Notification"

if (Test-Path $registryPath) {
    New-ItemProperty -Path $registryPath -Name "ShowBanner" -Value 0 -PropertyType DWORD -Force  # disable notification pop-ups
    New-ItemProperty -Path $registryPath -Name "AllowContentAboveLock" -Value 0 -PropertyType DWORD -Force  # disable app notifications on the lock screen
    New-ItemProperty -Path $registryPath -Name "SoundFile" -Value "" -PropertyType String -Force  # disable notification sound
} else {
    Write-Output "Registry path does not exist. No changes were made."
}
