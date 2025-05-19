


$CSVFilePath = "./devicesToDisable.csv"

$currentDate =Get-Date -Format "MM-dd-yyyy"

$DisableReason = "Disabled $currentDate via script" 
$ExtensionAttributeNumber = 1
$extensionAttributeName = "extensionAttribute$($ExtensionAttributeNumber)" # e.g., extensionAttribute1

Write-Host "Starting script: Disabling Entra Devices from CSV" -ForegroundColor Cyan

try {
    Import-Module Microsoft.Graph.Identity.DirectoryManagement -ErrorAction Stop
    Write-Host "Microsoft Graph Identity.DirectoryManagement module imported."

    $graphContext = Get-MgContext
    if (-not $graphContext) {
        Write-Host "Connecting to Microsoft Graph..."
        Connect-MgGraph -Scopes "Device.ReadWrite.All", "Directory.Read.All" 
        $graphContext = Get-MgContext 
        if (-not $graphContext) {
            Write-Error "Failed to connect to Microsoft Graph. Please ensure you have the necessary permissions and can authenticate."
            exit 1
        }
        Write-Host "Successfully connected to Microsoft Graph as $($graphContext.Account)" -ForegroundColor Green
    } else {
        Write-Host "Already connected to Microsoft Graph as $($graphContext.Account)" -ForegroundColor Green
    }
}
catch {
    Write-Error "Error importing Microsoft Graph module or connecting: $($_.Exception.Message)"
    Write-Warning "Please ensure the Microsoft Graph PowerShell SDK is installed: Install-Module Microsoft.Graph -Scope CurrentUser"
    exit 1
}

if (-not (Test-Path -Path $CSVFilePath -PathType Leaf)) {
    Write-Error "CSV file not found at path: $CSVFilePath"
    exit 1
}

try {
    $devicesToDisable = Import-Csv -Path $CSVFilePath
    if (-not $devicesToDisable) {
        Write-Warning "CSV file is empty or could not be read properly."
        exit 1
    }
    if (-not ($devicesToDisable[0].PSObject.Properties.Name -contains 'deviceName')) {
        Write-Error "CSV file must contain a header column named 'deviceName'."
        exit 1
    }
    Write-Host "Successfully imported $($devicesToDisable.Count) device entries from CSV." -ForegroundColor Green
}
catch {
    Write-Error "Error reading CSV file: $($_.Exception.Message)"
    exit 1
}

Write-Host "`nProcessing devices..."
$processedCount = 0
$successCount = 0
$failCount = 0

foreach ($deviceEntry in $devicesToDisable) {
    $processedCount++
    $deviceName = $deviceEntry.deviceName.Trim()

    if ([string]::IsNullOrWhiteSpace($deviceName)) {
        Write-Warning "Skipping entry $processedCount due to empty deviceName."
        $failCount++
        continue
    }

    Write-Host "`n[$($processedCount)/$($devicesToDisable.Count)] Processing device: '$($deviceName)'"

    try {
        
        Write-Host "Searching for device '$($deviceName)' in Entra ID..."
        $device = Get-MgDevice -Filter "displayName eq '$($deviceName)'" -Top 1 -ErrorAction Stop

        if (-not $device) {
            Write-Warning "Device '$($deviceName)' not found in Entra ID."
            $failCount++
            continue
        }

        $deviceId = $device.Id

        if (-not $device.AccountEnabled) {
            Write-Host "Device '$($deviceName)' (ID: $($deviceId)) is already disabled."
            $currentExtensionValue = $device.AdditionalProperties[$extensionAttributeName]
            if ($currentExtensionValue -ne $DisableReason) {
                Write-Host "Updating reason for already disabled device '$($deviceName)' to '$($DisableReason)' on attribute '$($extensionAttributeName)'..."
                $params = @{
                    "extensionAttributes" = @{
                        "$($extensionAttributeName)" = $DisableReason
                    }
                }
                Update-MgDevice -DeviceId $deviceId -BodyParameter $params -ErrorAction Stop
                Write-Host "Reason updated successfully for '$($deviceName)'." -ForegroundColor Green
            }
            $successCount++ 
            continue
        }

  
        Write-Host "Disabling device '$($deviceName)' (ID: $($deviceId)) and setting reason '$($DisableReason)' on attribute '$($extensionAttributeName)'..."

        $updateParams = @{
            "accountEnabled" = $false
            "extensionAttributes" = @{
                "$($extensionAttributeName)" = $DisableReason
            }
        }

        Update-MgDevice -DeviceId $deviceId -BodyParameter $updateParams -ErrorAction Stop

        Write-Host "Successfully disabled device '$($deviceName)' and set reason." -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Error "Failed to process device '$($deviceName)': $($_.Exception.Message)"
        if ($_.Exception.ErrorDetails) {
            Write-Error "Error Details: $($_.Exception.ErrorDetails | ConvertTo-Json -Depth 3)"
        }
        $failCount++
    }
}

Write-Host "`n--- Script Execution Summary ---" -ForegroundColor Cyan
Write-Host "Total entries in CSV: $($devicesToDisable.Count)"
Write-Host "Successfully processed/disabled: $successCount" -ForegroundColor Green
Write-Host "Failed to process: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })


# Disconnect-MgGraph

Write-Host "Script finished." -ForegroundColor Cyan