$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.WAU.Notification"

if (Test-Path $registryPath) {
    Remove-ItemProperty -Path $registryPath -Name "ShowBanner" -Force -ErrorAction SilentlyContinue  
    Remove-ItemProperty -Path $registryPath -Name "AllowContentAboveLock" -Force -ErrorAction SilentlyContinue 
    Remove-ItemProperty -Path $registryPath -Name "SoundFile" -Force -ErrorAction SilentlyContinue 
    
    Write-Output "Properties have been removed. System may revert to default notification settings."
} else {
    Write-Output "Registry path does not exist. No properties were removed."
}
