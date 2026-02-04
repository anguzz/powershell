Write-Host "Starting License Refresh, Identity Sync, and UI Fix..." -ForegroundColor Cyan

# 1. Refresh the Primary Refresh Token (PRT)
# This helps the device 'see' the user's M365 E3/E5 license assignment
Write-Host "Refreshing Entra ID Primary Refresh Token..."
dsregcmd /refreshprt

# Give the token a moment to catch up
Start-Sleep -Seconds 5

# 2. Ensure Software Protection Service is running
Write-Host "Configuring Software Protection Service..."
Set-Service sppsvc -StartupType Automatic
Start-Service sppsvc -ErrorAction SilentlyContinue

# 3. Force Windows Activation check-in
Write-Host "Triggering Windows Activation..."
cscript C:\Windows\System32\slmgr.vbs /ato

# 4. Disable the 'Not Activated' notifications/watermark
Write-Host "Applying UI notification suppression..."
$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform\Activation"

if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

New-ItemProperty -Path $regPath -Name "NotificationDisabled" -Value 1 -PropertyType DWORD -Force | Out-Null

Write-Host "Script Complete. A restart is recommended to refresh the UI." -ForegroundColor Green