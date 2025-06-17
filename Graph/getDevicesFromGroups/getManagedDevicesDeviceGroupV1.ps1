# possibly depcreated as of 6/17/25 after new graph module release

$groupId = "" 
$csvData = New-Object System.Collections.Generic.List[Object]

try {
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.readwrite.All", "GroupMember.readwrite.All", "Group.readwrite.All", "Directory.readwrite.All" -TenantId $tenantID
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
} catch {
    $connectErrorMessage = $_.Exception.Message
    Write-Error "Failed to connect to Microsoft Graph: $connectErrorMessage"
    exit
}

try {
    $group = Get-MgGroup -GroupId $groupId -Property "displayName" -ErrorAction Stop
    if ($null -eq $group) {
        Write-Error "Group with ID '$groupId' not found."
        exit
    }
    $groupDisplayNameForReport = $group.DisplayName
} catch {
    $groupErrorMessage = $_.Exception.Message
    Write-Error "Error retrieving group display name for ID '$groupId': $groupErrorMessage"
    exit
}

Write-Output "`n-----------------------------------------------------------------`n"
Write-Output "Starting device report for group: '$groupDisplayNameForReport' (ID: $groupId)"
Write-Output "Attempting to find Intune Managed Devices by their Display Name."
Write-Warning "IMPORTANT: Device display names (deviceNames in Intune) are not guaranteed to be unique. If multiple devices share the same name, this script may report on the first one found or all if multiple are returned by the filter."
Write-Output "`n-----------------------------------------------------------------`n"

try {
    $groupMembersUri = "https://graph.microsoft.com/v1.0/groups/$groupId/members/microsoft.graph.device?`$select=id,displayName&`$top=999"
    $groupDevicesResponse = Invoke-MgGraphRequest -Uri $groupMembersUri -Method GET -OutputType PSObject -ErrorAction Stop
} catch {
    $membersErrorMessage = $_.Exception.Message
    Write-Error "Error retrieving device members from group '$groupDisplayNameForReport': $membersErrorMessage"
    exit
}

if ($null -eq $groupDevicesResponse.value -or $groupDevicesResponse.value.Count -eq 0) {
    Write-Host "No Azure AD device members found in the group '$groupDisplayNameForReport'."
} else {
    Write-Output "Found $($groupDevicesResponse.value.Count) Azure AD device(s) in group '$groupDisplayNameForReport'. Processing each..."
    Write-Output "`n-----------------------------------------------------------------`n"

    $totalDevices = $groupDevicesResponse.value.Count
    $counter = 1

    foreach ($azureAdDeviceEntry in $groupDevicesResponse.value) {
    Write-Host "`n[$counter of $totalDevices] Processing device..."
        $azureAdDeviceId = $azureAdDeviceEntry.id
        $azureAdDeviceDisplayName = $azureAdDeviceEntry.displayName

        if (-not $azureAdDeviceDisplayName) {
            Write-Warning "Azure AD Device with ID '$azureAdDeviceId' has no displayName. Skipping."
            continue
        }

        Write-Host "Processing Azure AD Device: '$azureAdDeviceDisplayName' (AzureADDeviceId: $azureAdDeviceId)"
        Write-Host "Looking up Intune managed device with deviceName eq '$azureAdDeviceDisplayName'"

        try {
            $managedDevices = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$azureAdDeviceDisplayName'" -ErrorAction Stop

            if ($managedDevices) {
                $devicesToProcess = if ($managedDevices -is [array]) { $managedDevices } else { @($managedDevices) }

                if ($devicesToProcess.Count -gt 1) {
                    Write-Warning "Multiple Intune managed devices found with deviceName '$azureAdDeviceDisplayName'. Processing all found."
                }

                foreach ($device in $devicesToProcess) {
                    Write-Host "Found Intune managed device: '$($device.DeviceName)' (Intune ID: $($device.Id))" -ForegroundColor Green

                    try {
                        $managedDeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)?`$select=enrolledByUserPrincipalName,hardwareInformation,physicalMemoryInBytes"
                        $managedDeviceResponse = Invoke-MgGraphRequest -Uri $managedDeviceUri -Method GET -OutputType PSObject

                        $wiredIPv4Addresses = $managedDeviceResponse.hardwareInformation.wiredIPv4Addresses | Out-String
                        $ipAddressV4        = $managedDeviceResponse.hardwareInformation.ipAddressV4        | Out-String
                        $subnetAddress      = $managedDeviceResponse.hardwareInformation.subnetAddress      | Out-String
                        $subnetAddress      = $managedDeviceResponse.hardwareInformation.subnetAddress      | Out-String
                        $subnetAddress      = $managedDeviceResponse.hardwareInformation.subnetAddress      | Out-String
                        $enrolledByUPN      = $managedDeviceResponse.enrolledByUserPrincipalName
                        $totalStorageSpaceInBytes = $managedDeviceResponse.hardwareInformation.totalStorageSpace
                        $freeStorageSpaceInBytes   = $managedDeviceResponse.hardwareInformation.freeStorageSpace
                        $physicalMemoryInBytes     = $managedDeviceResponse.physicalMemoryInBytes
                        # https://learn.microsoft.com/en-us/answers/questions/853673/microsoft-graph-api-physical-memory-info-for-manag
                        # very jank, physical memory will not populate if not called WITH hardware info in the same api call. 
                    } catch {
                        Write-Warning "Failed to get hardware info for device ID: $($device.id). $_"
                        $wiredIPv4Addresses = $ipAddressV4 = $subnetAddress = $enrolledByUPN = "N/A"
                    }

                    $deviceObject = [PSCustomObject]@{
                        "AAD Device Name"     = $azureAdDeviceDisplayName
                        "Intune Device Name"  = $device.deviceName
                        "OS"                  = $device.operatingSystem
                        "OS version"          = $device.osVersion
                        "Manufacturer"        = $device.manufacturer
                        "Model"               = $device.model
                        "Serial number"       = $device.serialNumber
                        "Primary user UPN"    = $device.userPrincipalName
                        "Enrolled By UPN"     = $enrolledByUPN
                        "Stored Space"        = $totalStorageSpaceInBytes 
                        "Free Space"          = $freeStorageSpaceInBytes 
                        "Physical Memory"    = $physicalMemoryInBytes
                        "Wired IPv4"          = $wiredIPv4Addresses.Trim()
                        "IPv4 Address"        = $ipAddressV4.Trim()
                        "Subnet"              = $subnetAddress.Trim()
                        "Intune Device ID"    = $device.Id
                        "Azure AD Device ID"  = $device.azureADDeviceId
                        "AAD ID from Group"   = $azureAdDeviceId
                        "Management State"    = $device.ManagementState
                        "Last Sync"           = $device.LastSyncDateTime
                    }

                    $csvData.Add($deviceObject)
                }
            } else {
    Write-Host "No Intune-managed device found with deviceName eq '$azureAdDeviceDisplayName' (for AAD Device ID: $azureAdDeviceId)"

    $deviceObject = [PSCustomObject]@{
        "AAD Device Name"     = $azureAdDeviceDisplayName
        "Intune Device Name"  = "Not intune managed"
        "OS"                  = "-"
        "OS version"          = "-"
        "Manufacturer"        = "-"
        "Model"               = "-"
        "Serial number"       = "-"
        "Primary user UPN"    = "-"
        "Enrolled By UPN"     = "-"
        "Stored Space"        = "-"
        "Free Space"          = "-"
        "Physical Memory"     = "-"
        "Wired IPv4"          = "-"
        "IPv4 Address"        = "-"
        "Subnet"              = "-"
        "Intune Device ID"    = "-"
        "Azure AD Device ID"  = "-"
        "AAD ID from Group"   = $azureAdDeviceId
        "Management State"    = "Not Found"
        "Last Sync"           = "-"
    }

    $csvData.Add($deviceObject)            
    }
        } catch {
            $deviceErrorMessage = $_.Exception.Message
            Write-Warning "Failed to retrieve Intune device details for Azure AD Device '$azureAdDeviceDisplayName' (ID: $azureAdDeviceId). Error: $deviceErrorMessage"

            $deviceObject = [PSCustomObject]@{
                "AAD Device Name"     = $azureAdDeviceDisplayName
                "Intune Device Name"  = "ERROR RETRIEVING"
                "OS"                  = $deviceErrorMessage
                "Azure AD Device ID"  = "Error"
                "AAD ID from Group"   = $azureAdDeviceId
                "Management State"    = "Error"
            }

            $csvData.Add($deviceObject)
        }
        $counter++

        Write-Output "---"
    }
}

# CSV Export Logic
if ($csvData.Count -gt 0) {
    $currentDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $safeGroupDisplayName = $groupDisplayNameForReport -replace '[^a-zA-Z0-9]', '_'
    $csvFileName = "ManagedDevices_ByDisplayName_FromGroup_$($safeGroupDisplayName)_$currentDate.csv"

    $scriptPath = $PSScriptRoot
    if (-not $scriptPath) { $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition -ErrorAction SilentlyContinue }
    if (-not $scriptPath) { $scriptPath = Get-Location }

    $csvPath = Join-Path -Path $scriptPath -ChildPath $csvFileName

    try {
        $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Output "`n-----------------------------------------------------------------`n"
        Write-Output "Device report successfully exported to: $csvPath" -ForegroundColor Green
        Write-Output "Total Azure AD devices in group processed: $($groupDevicesResponse.value.Count)"
        Write-Output "Total records in CSV: $($csvData.Count)"
        Write-Output "-----------------------------------------------------------------`n"
    } catch {
        $exportErrorMessage = $_.Exception.Message
        Write-Error "Failed to export CSV data to '$csvPath'. Error: $exportErrorMessage"
    }
} else {
    Write-Output "`nNo data to export to CSV for group '$groupDisplayNameForReport'."
}

# Disconnect-MgGraph
