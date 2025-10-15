
param(
    [switch]$WhatIf
)


# --- config ---
$CompanyName = "ADD_ORG_NAME" #used for machine renaming CompanyName-SerialNumber
$ExcludeList = "MachineName1, MachineName2, MachineName3" # Add device names to this comma-separated string to exclude them from renaming.

# ---------------------

# Define required module
$requiredModule = "Microsoft.Graph.DeviceManagement"

# Ensure the required module is available
if (-not(Get-Module -Name $requiredModule -ListAvailable)) {
    Write-Error "$requiredModule module not found. Please install it by running: Install-Module $requiredModule"
    return
}
Import-Module $requiredModule

# Prepare the exclusion array by splitting the string and trimming whitespace
$exclusionArray = $ExcludeList -split ',' | ForEach-Object { $_.Trim() }

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
# Connect to Graph. Scopes are requested and consented to interactively the first time.
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"

Write-Host "Retrieving Windows physical devices from Intune..." -ForegroundColor Cyan
# Get all managed devices, then filter for Windows devices that are not identified as virtual machines.
$devices = Get-MgDeviceManagementManagedDevice -All `
    | Where-Object { $_.OperatingSystem -eq "Windows" -and $_.Model -notlike "*Virtual*" }

Write-Host "`nFound $($devices.Count) total Windows physical devices to evaluate.`n" -ForegroundColor Yellow

# Initialize arrays for tracking
$reportData = @()
$summary = [PSCustomObject]@{
    TotalDevicesEvaluated = $devices.Count
    RenameQueued          = 0
    AlreadyCompliant      = 0
    SkippedNoSerial       = 0
    SkippedExcluded       = 0
    Errors                = 0
}

# Process Devices
foreach ($device in $devices) {
    # Create a report object for every device
    $reportObject = [PSCustomObject]@{
        Timestamp         = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        OldDeviceName     = $device.DeviceName
        NewDeviceName     = "" # Will populate later
        SerialNumber      = $device.SerialNumber
        IntuneDeviceID    = $device.Id
        Status            = "" # Will populate later
    }

    # Check against the exclusion list first
    if ($exclusionArray -contains $device.DeviceName) {
        Write-Host "Skipping '$($device.DeviceName)' as it is in the exclusion list." -ForegroundColor DarkGray
        $summary.SkippedExcluded++
        $reportObject.Status = "Skipped (Excluded)"
        $reportData += $reportObject
        continue
    }

    $serial = $device.SerialNumber
    if ([string]::IsNullOrEmpty($serial)) {
        Write-Warning "Skipping device '$($device.DeviceName)' (ID: $($device.Id)) because it has no serial number."
        $summary.SkippedNoSerial++
        $reportObject.Status = "Skipped (No Serial)"
        $reportData += $reportObject
        continue
    }

    $newName = "$CompanyName-$serial"
    # NetBIOS names are limited to 15 characters. Truncating ensures compatibility.
    if ($newName.Length -gt 15) {
        $newName = $newName.Substring(0, 15)
    }
    $reportObject.NewDeviceName = $newName

    # Skip renaming if the device name already conforms to the standard.
    if ($device.DeviceName -eq $newName) {
        Write-Host "Already compliant: $($device.DeviceName)" -ForegroundColor Green
        $summary.AlreadyCompliant++
        $reportObject.Status = "Already Compliant"
        $reportData += $reportObject
        continue
    }

    if ($WhatIf) {
        Write-Host "[WhatIf] Would rename '$($device.DeviceName)' to '$newName'" -ForegroundColor Cyan
        $reportObject.Status = "WhatIf: Rename Required"
        $summary.RenameQueued++ # In WhatIf mode, we count what *would* be queued
    }
    else {
        Write-Host "Queueing rename for '$($device.DeviceName)' -> '$newName'..." -ForegroundColor Yellow
        try {
            # Use direct API call via Invoke-MgGraphRequest to perform the rename action.
            $body = @{ deviceName = $newName } | ConvertTo-Json
            $updateUrl = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.Id)/setDeviceName"

            Invoke-MgGraphRequest -Method POST -Uri $updateUrl -Body $body

            Write-Host "  Rename action queued successfully." -ForegroundColor DarkGreen
            $summary.RenameQueued++
            $reportObject.Status = "Rename Queued"
        }
        catch {
            Write-Warning "  Failed to queue rename for '$($device.DeviceName)': $_"
            $summary.Errors++
            $reportObject.Status = "Error"
        }
    }
    # Add the completed report object to our data array
    $reportData += $reportObject
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
Write-Host "`nDisconnected from Microsoft Graph."

# Generate CSV Report
if ($reportData.Count -gt 0) {
    $reportFileName = "IntuneDeviceRename_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $reportPath = Join-Path -Path $PSScriptRoot -ChildPath $reportFileName
    try {
        $reportData | Export-Csv -Path $reportPath -NoTypeInformation
        Write-Host "`nAction report saved to: $reportPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to save report to '$reportPath': $_"
    }
}

# Display Summary
if ($WhatIf) {
    Write-Host "`nDry run complete. No devices were renamed." -ForegroundColor Green
    Write-Host "---------------------"
    Write-Host "Total devices evaluated: $($summary.TotalDevicesEvaluated)"
    Write-Host "Would be renamed: $($summary.RenameQueued)" -ForegroundColor Yellow
    Write-Host "Devices already compliant: $($summary.AlreadyCompliant)" -ForegroundColor Cyan
    Write-Host "Devices skipped (in exclusion list): $($summary.SkippedExcluded)" -ForegroundColor DarkGray
    Write-Host "Devices skipped (no serial): $($summary.SkippedNoSerial)" -ForegroundColor Yellow
} else {
    Write-Host "`nOperation Summary:" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host "Total devices evaluated: $($summary.TotalDevicesEvaluated)"
    Write-Host "Rename actions queued: $($summary.RenameQueued)" -ForegroundColor Green
    Write-Host "Devices already compliant: $($summary.AlreadyCompliant)" -ForegroundColor Cyan
    Write-Host "Devices skipped (in exclusion list): $($summary.SkippedExcluded)" -ForegroundColor DarkGray
    Write-Host "Devices skipped (no serial): $($summary.SkippedNoSerial)" -ForegroundColor Yellow
    Write-Host "Errors encountered: $($summary.Errors)" -ForegroundColor Red
    Write-Host "`nAll rename requests submitted. Devices will update their names after their next Intune check-in." -ForegroundColor Green
}