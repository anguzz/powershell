<#
.SYNOPSIS
Invoke-StorageStackDiagnostic.ps1

.DESCRIPTION
Collects storage stack diagnostics remotely to help troubleshoot BSODs,
driver issues, and firmware problems without needing crash dumps.

Checks included:
- Disk model, firmware, and health
- Physical disk health
- Storage / NVMe driver versions
- BIOS version
- Loaded storage drivers
- Recent storage-related system events
#>

Write-Output "========== Storage Stack Diagnostic =========="
Write-Output "Hostname: $env:COMPUTERNAME"
Write-Output "Time: $(Get-Date)"
Write-Output ""

# --------------------------------------------------
# Disk Hardware
# --------------------------------------------------
Write-Output "---- Disk Hardware ----"
try {
    Get-CimInstance Win32_DiskDrive |
    Select Model, FirmwareRevision, SerialNumber, Status |
    Format-Table -AutoSize
}
catch {
    Write-Output "Unable to retrieve disk hardware info."
}
Write-Output ""

# --------------------------------------------------
# Physical Disk Health
# --------------------------------------------------
Write-Output "---- Physical Disk Health ----"
try {
    Get-PhysicalDisk |
    Select FriendlyName, MediaType, HealthStatus, OperationalStatus, FirmwareVersion |
    Format-Table -AutoSize
}
catch {
    Write-Output "Get-PhysicalDisk not available."
}
Write-Output ""

# --------------------------------------------------
# Storage / NVMe Drivers
# --------------------------------------------------
Write-Output "---- Storage / NVMe Drivers ----"
try {
    Get-WmiObject Win32_PnPSignedDriver |
    Where-Object { $_.DeviceName -match "NVMe|Storage|SCSI" } |
    Select DeviceName, DriverVersion, DriverProviderName, DriverDate |
    Format-Table -AutoSize
}
catch {
    Write-Output "Unable to retrieve storage driver information."
}
Write-Output ""

# --------------------------------------------------
# Loaded Storage Driver Modules
# --------------------------------------------------
Write-Output "---- Loaded Storage Driver Modules ----"
try {
    driverquery | findstr /i "nvme storport iaStor"
}
catch {
    Write-Output "Unable to retrieve loaded driver modules."
}
Write-Output ""

Write-Output "---- Storage Controllers (SCSIAdapter Class) ----"
try {
    Get-PnpDevice -Class SCSIAdapter |
    Select-Object Status, Class, FriendlyName, InstanceId |
    Format-Table -AutoSize
}
catch {
    Write-Output "Unable to retrieve storage controllers."
}
Write-Output ""

# --------------------------------------------------
# BIOS Information
# --------------------------------------------------
Write-Output "---- BIOS Information ----"
try {
    Get-CimInstance Win32_BIOS |
    Select Manufacturer, SMBIOSBIOSVersion, ReleaseDate |
    Format-Table -AutoSize
}
catch {
    Write-Output "Unable to retrieve BIOS information."
}
Write-Output ""

# --------------------------------------------------
# Virtualization Based Security
# --------------------------------------------------
Write-Output "---- Virtualization / VBS State (Best Effort) ----"
try {
    $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction Stop
    $dg | Select-Object VirtualizationBasedSecurityStatus, SecurityServicesRunning | Format-List
}
catch {
    Write-Output "Win32_DeviceGuard not available on this system (skipping)."
}
Write-Output ""

# --------------------------------------------------
# Recent Storage Related Events
# --------------------------------------------------
Write-Output "---- Recent Crash Markers (Kernel-Power 41, BugCheck 1001) ----"
try {
    Get-WinEvent -FilterHashtable @{LogName="System"; ID=41,1001} -MaxEvents 10 -ErrorAction SilentlyContinue |
    Select TimeCreated, Id, ProviderName, Message |
    Format-List
}
catch { Write-Output "Unable to query crash marker events." }
Write-Output ""

Write-Output "---- Recent Storage Error Indicators (Disk/NTFS/Storport) ----"
try {
    # Common storage-related event IDs across Disk/NTFS/Storport stacks
    $storageIds = 7,11,51,55,57,129,153,157
    $events = Get-WinEvent -FilterHashtable @{LogName="System"; ID=$storageIds} -MaxEvents 30 -ErrorAction SilentlyContinue

    if (-not $events) {
        Write-Output "No recent storage error indicator events found."
    }
    else {
        # Only show the most useful fields; message can be long
        $events |
        Select TimeCreated, Id, ProviderName, LevelDisplayName, Message |
        Format-List
    }
}
catch {
    Write-Output "Unable to query storage indicator events."
}
Write-Output ""

Write-Output ""
Write-Output "========== Storage Stack Diagnostic Complete =========="