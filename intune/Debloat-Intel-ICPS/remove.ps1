$ErrorActionPreference = "SilentlyContinue"

# --- Logging setup ---
$LogDir = "C:\Logs"
if (!(Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force | Out-Null }
$LogFile = Join-Path $LogDir "Remove_ICPS_$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $LogFile -Force

Write-Host "----- Starting Intel Connectivity Performance Suite (ICPS) Full Cleanup -----"

#  Stop, disable, and DELETE service + files
$serviceName = "IntelConnectivityNetworkService"
$serviceDir = "C:\WINDOWS\System32\drivers\Intel\ICPS"
Write-Host "Stopping, disabling, and deleting service: $serviceName"

Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
Set-Service -Name $serviceName -StartupType Disabled -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "Deleting service entry '$serviceName'..."
    sc.exe delete $serviceName | Tee-Object -FilePath $LogFile -Append
} else {
    Write-Host "Service entry '$serviceName' already removed."
}

if (Test-Path $serviceDir) {
    Write-Host "Removing service executable and folder at $serviceDir"
    Remove-Item -Path $serviceDir -Recurse -Force -ErrorAction SilentlyContinue
}

#  Remove Appx / MSIX package (UWP version)
Write-Host "Checking for ICPS Appx/MSIX package..."
Get-AppxPackage -AllUsers | Where-Object { $_.Name -like "AppUp.IntelConnectivityPerformanceSuite*" } | ForEach-Object {
    Write-Host "Removing UWP package $($_.PackageFullName)"
    Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
}

#  Detect and remove Win32/MSI package
Write-Host "Checking for ICPS Win32/MSI package..."
$msiPackage = Get-Package -Name "*Intel Connectivity Performance Suite*" -ErrorAction SilentlyContinue
if ($msiPackage) {
    Write-Host "Found Win32/MSI package: $($msiPackage.Name)"
    Write-Host "Attempting silent uninstall..."
    try {
        Uninstall-Package -Name $msiPackage.Name -ProviderName MSI -Quiet -ErrorAction Stop | Tee-Object -FilePath $LogFile -Append
        Write-Host "Successfully uninstalled MSI package."
    } catch {
        Write-Host " Failed to uninstall MSI package automatically $($_.Exception.Message)"
    }
} else {
    Write-Host "No ICPS Win32/MSI package found."
}

#  Detect and remove staged ICPS driver packages
Write-Host "Enumerating ICPS driver packages..."
$driverOutput = pnputil /enum-drivers | Out-String
$driverStanzas = $driverOutput -split '(?=Published Name)'
$icpsDrivers = @()

foreach ($stanza in $driverStanzas) {
    if ($stanza -match "icps") {
        if ($stanza -match "Published Name:\s*(oem\d+\.inf)") {
            $oemName = $matches[1]
            $icpsDrivers += $oemName
            $originalName = ($stanza | Select-String 'Original Name').ToString().Trim() -replace 'Original Name:\s*', ''
            Write-Host "Found ICPS-related driver $oemName (Original $originalName)"
        }
    }
}

if ($icpsDrivers.Count -gt 0) {
    Write-Host "Found ICPS-related driver packages: $($icpsDrivers -join ', ')"
    foreach ($drv in $icpsDrivers | Sort-Object -Unique) {
        Write-Host "Deleting driver package $drv"
        pnputil /delete-driver $drv /uninstall /force 
    }
    Write-Host "Driver cleanup complete - reboot will be required."
} else {
    Write-Host "No ICPS driver packages found in driver store."
}
# Remove leftover registry keys
$regPaths = @(
    "HKLM:\SOFTWARE\Classes\PackagedCom\Package\AppUp.IntelConnectivityPerformanceSuite_*",
    "HKLM:\SOFTWARE\Intel\ICPS"
)
foreach ($path in $regPaths) {
    if (Test-Path $path) {
        Write-Host "Removing leftover registry path $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#  Remove leftover folders
$pathsToClean = @(
    "C:\ProgramData\Microsoft\Windows\AppRepository\Packages\AppUp.IntelConnectivityPerformanceSuite*",
    "C:\Users\*\AppData\Local\Packages\AppUp.IntelConnectivityPerformanceSuite*"
)
foreach ($p in $pathsToClean) {
    Write-Host "Cleaning leftover folder path(s) $p"
    Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

#  Post-cleanup verification
Write-Host "Verifying ICPS driver removal..."
$remainingDrivers = pnputil /enum-drivers | Select-String "icps"
if ($remainingDrivers) {
    Write-Host "ICPS drivers still detected (a reboot is likely required to finalize)"
    Write-Host $remainingDrivers
} else {
    Write-Host "No ICPS drivers remaining in DriverStore."
}

$remainingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($remainingService) {
    Write-Host "Service '$serviceName' is still detected."
} else {
    Write-Host "Service '$serviceName' successfully removed."
}

Write-Host "Intel Connectivity Performance Suite cleanup complete."
Write-Host "A reboot is highly recommended to finalize removal."

Stop-Transcript
exit 0
