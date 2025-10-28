# ==========================================
# Re-enable Entra Devices from CSV (Undo Script)
# ==========================================

$CSVFilePath = "./devicesToDisable.csv" # Same CSV used before
$ExtensionAttributeNumber = 2
$extensionAttributeName = "extensionAttribute$($ExtensionAttributeNumber)"
$ReenableReason = "Re-enabled $(Get-Date -Format 'MM-dd-yyyy')"

Write-Host "Starting script: Re-enabling Entra Devices from CSV" -ForegroundColor Cyan

try {
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    Write-Host "Microsoft Graph module loaded."
    $graphContext = Get-MgContext
    if (-not $graphContext) {
        Write-Host "Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "Device.ReadWrite.All", "Directory.Read.All"
        $graphContext = Get-MgContext
    }
    Write-Host "Connected as $($graphContext.Account)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import or connect to Graph: $($_.Exception.Message)"
    exit 1
}

if (-not (Test-Path $CSVFilePath)) {
    Write-Error "CSV not found: $CSVFilePath"
    exit 1
}

$devices = Import-Csv $CSVFilePath
if (-not ($devices[0].PSObject.Properties.Name -contains 'deviceName')) {
    Write-Error "CSV must contain a 'deviceName' column."
    exit 1
}

$processed = 0; $success = 0; $fail = 0

foreach ($entry in $devices) {
    $processed++
    $deviceName = $entry.deviceName.Trim()
    if ([string]::IsNullOrWhiteSpace($deviceName)) {
        Write-Warning "Skipping blank entry ($processed)."
        continue
    }

    Write-Host "`n[$processed/$($devices.Count)] Processing: $deviceName"

    try {
        $device = Get-MgDevice -Filter "displayName eq '$($deviceName)'" -Top 1 -ErrorAction Stop
        if (-not $device) {
            Write-Warning "Device '$deviceName' not found."
            $fail++
            continue
        }

        $deviceId = $device.Id

        if ($device.AccountEnabled) {
            Write-Host "Device '$deviceName' already enabled."
            $success++
            continue
        }

        Write-Host "Re-enabling device '$deviceName' and updating attribute '$extensionAttributeName'..." -ForegroundColor Yellow

        $params = @{
            "accountEnabled" = $true
            "extensionAttributes" = @{
                "$($extensionAttributeName)" = $ReenableReason  # Or set to $null to clear it
            }
        }

        Update-MgDevice -DeviceId $deviceId -BodyParameter $params -ErrorAction Stop
        Write-Host "Device '$deviceName' re-enabled successfully." -ForegroundColor Green
        $success++
    }
    catch {
        Write-Error "Failed to re-enable '$deviceName': $($_.Exception.Message)"
        $fail++
    }
}

Write-Host "`n--- Summary ---" -ForegroundColor Cyan
Write-Host "Total processed: $processed"
Write-Host "Re-enabled successfully: $success" -ForegroundColor Green
Write-Host "Failed: $fail" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "`nScript completed." -ForegroundColor Cyan
