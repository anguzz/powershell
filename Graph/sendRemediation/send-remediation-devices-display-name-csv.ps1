
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "devices.csv"


function Get-IntuneManagedDeviceIdByName {
    param(
        [string]$DeviceName
    )

    Write-Host "`nAttempting to find Intune Managed Device with Intune deviceName: $DeviceName" 

    try {

        $intuneDevice = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'" -Top 1 -ErrorAction Stop

        if ($intuneDevice) {
 
            Write-Host "Intune Managed Device ID found: $($intuneDevice.Id) for Intune deviceName: $($intuneDevice.DeviceName)"
            return $intuneDevice.Id 
        } else {
            Write-Host "No Intune Managed Device found with Intune deviceName: $DeviceName"
            return $null
        }
    } catch {
        Write-Warning "Error retrieving Intune Managed Device with Intune deviceName '$DeviceName': $($_.Exception.Message)"
        return $null
    }
}

function Invoke-IntuneDeviceRemediation {
    param(
        [string]$ManagedDeviceId,
        [string]$RemediationScriptId
    )

    Write-Host "Attempting to trigger Remediation ID '$RemediationScriptId' on device ID '$ManagedDeviceId'..."

    $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$ManagedDeviceId/initiateOnDemandProactiveRemediation"
    $body = @{
        scriptPolicyId = $RemediationScriptId
    } | ConvertTo-Json

    try {
        Invoke-MgGraphRequest -Uri $uri -Method POST -Body $body -ErrorAction Stop
        Write-Host "Successfully initiated remediation on device ID '$ManagedDeviceId'."
        return $true
    } catch {
        Write-Warning "Failed to initiate remediation on device ID '$ManagedDeviceId'. Error: $($_.Exception.Message)"

        return $false
    }
}

try {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All" -NoWelcome 
    Write-Host "Successfully connected to Microsoft Graph and switched to beta profile."
} catch {
    Write-Error "Failed to connect to Microsoft Graph. Please check permissions and module installation. Error: $($_.Exception.Message)"
    exit 1
}

$remediationScriptId = Read-Host -Prompt "Enter the Proactive Remediation Script ID (GUID)"
if (-not ($remediationScriptId -as [guid])) {
    Write-Error "Invalid Remediation Script ID format. Please enter a valid GUID."
    exit 1
}

if (-not (Test-Path $csvPath)) {
    Write-Error "CSV file not found at $csvPath"
    exit 1
}

try {
    $devicesToProcess = Import-Csv -Path $csvPath
    if (-not $devicesToProcess) {
        Write-Warning "No devices found in the CSV file: $csvPath"
        exit
    }
} catch {
    Write-Error "Failed to read or parse the CSV file. Error: $($_.Exception.Message)"
    exit 1
}


Write-Output "`n-----------------------------------------------------------------"
Write-Output "Beginning Proactive Remediation triggering process."
Write-Output "Remediation Script ID to be used: $remediationScriptId"
Write-Output "Total devices to process from CSV: $($devicesToProcess.Count)"
Write-Output "-----------------------------------------------------------------`n"

$processedCount = 0
$successCount = 0
$notFoundCount = 0
$errorCount = 0

foreach ($deviceEntry in $devicesToProcess) {
    $processedCount++
    $currentDeviceName = $deviceEntry.DeviceName

    if ([string]::IsNullOrWhiteSpace($currentDeviceName)) {
        Write-Warning "Skipping row $processedCount as DeviceName is empty."
        continue
    }

    Write-Output "Processing device $processedCount of $($devicesToProcess.Count): $currentDeviceName"

    $managedDeviceId = Get-IntuneManagedDeviceIdByName -DeviceName $currentDeviceName

    if ($managedDeviceId) {
        $result = Invoke-IntuneDeviceRemediation -ManagedDeviceId $managedDeviceId -RemediationScriptId $remediationScriptId
        if ($result) {
            $successCount++
        } else {
            $errorCount++
        }
    } else {
        Write-Warning "Skipping remediation for '$currentDeviceName' as its ID was not found."
        $notFoundCount++
    }
    Write-Output "-----------------------------------------------------------------`n"
}

Write-Output "Remediation triggering process completed."
Write-Output "Summary:"
Write-Output "Successfully initiated remediation on: $successCount device(s)."
Write-Output "Devices not found in Intune: $notFoundCount device(s)."
Write-Output "Failed to initiate remediation (errors): $errorCount device(s)."

# Disconnect-MgGraph 
