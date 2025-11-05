$ErrorActionPreference = "SilentlyContinue"

# --- Optional logging (safe to disable for production) ---
$LogDir = "C:\ProgramData\IntuneScripts\Logs"
if (!(Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogDir "Detect_ICPS_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $LogFile -Force

# --- Detection ---
$icpsDetected = $false

#   Check for UWP/MSIX Appx package (all users)
$appx = Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "AppUp.IntelConnectivityPerformanceSuite*" }
if ($appx) {
    Write-Output "Detected ICPS Appx package: $($appx.PackageFullName)"
    $icpsDetected = $true
}

#   Check for ICPS driver packages still staged
$driverCheck = pnputil /enum-drivers | Select-String "icps"
if ($driverCheck) {
    Write-Output "Detected ICPS driver package(s):"
    Write-Output $driverCheck
    $icpsDetected = $true
}

if ($icpsDetected) {
    Write-Output "ICPS detected. Exiting with code 1 for remediation trigger."
    Stop-Transcript
    exit 1
}
else {
    Write-Output "ICPS not detected. Exiting with code 0 (compliant)."
    Stop-Transcript
    exit 0
}
