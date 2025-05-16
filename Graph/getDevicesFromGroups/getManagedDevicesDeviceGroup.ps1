
$groupId = "" # Set the group ID here
$csvData = New-Object System.Collections.Generic.List[Object]

try {
 
    Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "GroupMember.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All" #, "Device.Read.All" potentially
 
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
}
catch {
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
}
catch {
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
}
catch {
    $membersErrorMessage = $_.Exception.Message
    Write-Error "Error retrieving device members from group '$groupDisplayNameForReport': $membersErrorMessage"
    exit
}

if ($null -eq $groupDevicesResponse.value -or $groupDevicesResponse.value.Count -eq 0) {
    Write-Host "No Azure AD device members found in the group '$groupDisplayNameForReport'."
} else {
    Write-Output "Found $($groupDevicesResponse.value.Count) Azure AD device(s) in group '$groupDisplayNameForReport'. Processing each..."
    Write-Output "`n-----------------------------------------------------------------`n"

    foreach ($azureAdDeviceEntry in $groupDevicesResponse.value) {
        $azureAdDeviceId = $azureAdDeviceEntry.id
        $azureAdDeviceDisplayName = $azureAdDeviceEntry.displayName

        if (-not $azureAdDeviceDisplayName) {
            Write-Warning "Azure AD Device with ID '$azureAdDeviceId' has no displayName. Skipping."
            Continue
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

                    $enrolledByUPN_detail = "N/A"
                    $wiredIPv4Addresses_detail = "N/A"
                    $ipAddressV4_detail = "N/A"
                    $subnetAddress_detail = "N/A" 
                    $additionalDetailError = $null

                    try {
                       
                        $managedDeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.Id)?`$select=enrolledByUserPrincipalName,hardwareInformation"
                        Write-Host "Fetching additional details for '$($device.DeviceName)' (Intune ID: $($device.Id)) from $managedDeviceUri"
                        $managedDeviceDetailResponse = Invoke-MgGraphRequest -Uri $managedDeviceUri -Method GET -OutputType PSObject -ErrorAction Stop

                        if ($null -ne $managedDeviceDetailResponse) {
                            $enrolledByUPN_detail = $managedDeviceDetailResponse.enrolledByUserPrincipalName
                            if (-not $enrolledByUPN_detail) { $enrolledByUPN_detail = "N/A" }

                            if ($null -ne $managedDeviceDetailResponse.hardwareInformation) {
                                $hwInfo = $managedDeviceDetailResponse.hardwareInformation

                                # wiredIPv4Addresses
                                if ($hwInfo.PSObject.Properties.Name -contains 'wiredIPv4Addresses' -and $null -ne $hwInfo.wiredIPv4Addresses) {
                                    if ($hwInfo.wiredIPv4Addresses -is [array]) {
                                        $wiredIPv4Addresses_detail = ($hwInfo.wiredIPv4Addresses -join "; ").Trim()
                                    } else {
                                        $wiredIPv4Addresses_detail = ($hwInfo.wiredIPv4Addresses | Out-String).Trim() -replace "[\r\n]+", "; "
                                    }
                                } else { $wiredIPv4Addresses_detail = "N/A (not present)" }
                                if (-not $wiredIPv4Addresses_detail) {$wiredIPv4Addresses_detail = "N/A"}


                                # ipAddressV4 (typically a single string from Intune)
                                if ($hwInfo.PSObject.Properties.Name -contains 'ipAddressV4' -and $null -ne $hwInfo.ipAddressV4) {
                                     $ipAddressV4_detail = ($hwInfo.ipAddressV4 | Out-String).Trim() -replace "[\r\n]+", "; "
                                } else { $ipAddressV4_detail = "N/A (not present)" }
                                if (-not $ipAddressV4_detail) {$ipAddressV4_detail = "N/A"}

                                # subnetAddress (user-specified name, may not be a standard Graph API direct property under hardwareInformation)
                                # Standard properties might be defaultGateway, subnetMask. This will look for 'subnetAddress'.
                                if ($hwInfo.PSObject.Properties.Name -contains 'subnetAddress' -and $null -ne $hwInfo.subnetAddress) {
                                    if ($hwInfo.subnetAddress -is [array]) {
                                        $subnetAddress_detail = ($hwInfo.subnetAddress -join "; ").Trim()
                                    } else {
                                        $subnetAddress_detail = ($hwInfo.subnetAddress | Out-String).Trim() -replace "[\r\n]+", "; "
                                    }
                                } else { $subnetAddress_detail = "N/A (not present)" }
                                if (-not $subnetAddress_detail) {$subnetAddress_detail = "N/A"}

                            } else {
                                Write-Warning "Hardware information object not found for device '$($device.DeviceName)' (Intune ID: $($device.Id))."
                            }
                        } else {
                             Write-Warning "No response from additional details query for device '$($device.DeviceName)' (Intune ID: $($device.Id))."
                        }
                    }
                    catch {
                        $additionalDetailError = $_.Exception.Message
                        Write-Warning "Error fetching additional details for device '$($device.DeviceName)' (Intune ID: $($device.Id)): $additionalDetailError"
                        $enrolledByUPN_detail = "Error fetching"
                        $wiredIPv4Addresses_detail = "Error fetching"
                        $ipAddressV4_detail = "Error fetching"
                        $subnetAddress_detail = "Error fetching"
                    }

                    $deviceObject = [PSCustomObject]@{
                        "AAD Device Name"    = $azureAdDeviceDisplayName
                        "Intune Device Name" = $device.deviceName
                        "OS"                 = $device.operatingSystem
                        "OS version"         = $device.osVersion
                        "Manufacturer"       = $device.manufacturer
                        "Model"              = $device.model
                        "Serial number"      = $device.serialNumber
                        "Primary user UPN"   = $device.userPrincipalName
                        "Enrolled By UPN"    = $enrolledByUPN_detail
                        "Wired IPv4 Addresses" = $wiredIPv4Addresses_detail
                        "IP Address V4"      = $ipAddressV4_detail
                        "Subnet Address"     = $subnetAddress_detail
                        "Intune Device ID"   = $device.Id
                        "Azure AD Device ID" = $device.azureADDeviceId
                        "AAD ID from Group"  = $azureAdDeviceId
                        "Management State"   = $device.ManagementState
                        "Last Sync"          = $device.LastSyncDateTime
                        "Additional Detail Error" = if($additionalDetailError){$additionalDetailError}else{"None"}
                    }
                    $csvData.Add($deviceObject)
                }
            } else {
                Write-Host "No Intune-managed device found with deviceName eq '$azureAdDeviceDisplayName' (for AAD Device ID: $azureAdDeviceId)"
                $deviceObject = [PSCustomObject]@{
                    "AAD Device Name"    = $azureAdDeviceDisplayName
                    "Intune Device Name" = "NOT FOUND IN INTUNE BY DISPLAYNAME"
                    "OS"                 = "N/A"
                    "OS version"         = "N/A"
                    "Manufacturer"       = "N/A"
                    "Model"              = "N/A"
                    "Serial number"      = "N/A"
                    "Primary user UPN"   = "N/A"
                    "Enrolled By UPN"    = "N/A"
                    "Wired IPv4 Addresses" = "N/A"
                    "IP Address V4"      = "N/A"
                    "Subnet Address"     = "N/A"
                    "Intune Device ID"   = "N/A"
                    "Azure AD Device ID" = "N/A" # Was Intune's AAD ID, now N/A as no Intune device
                    "AAD ID from Group"  = $azureAdDeviceId
                    "Management State"   = "Not Found"
                    "Last Sync"          = "N/A"
                    "Additional Detail Error" = "N/A"
                }
                $csvData.Add($deviceObject)
            }
        } catch {
            $deviceErrorMessage = $_.Exception.Message
            Write-Warning "Failed to retrieve Intune device details for Azure AD Device '$azureAdDeviceDisplayName' (ID: $azureAdDeviceId). Error: $deviceErrorMessage"
            $deviceObject = [PSCustomObject]@{
                "AAD Device Name"    = $azureAdDeviceDisplayName
                "Intune Device Name" = "ERROR RETRIEVING INTUNE INFO"
                "OS"                 = $deviceErrorMessage # Storing main error in OS field as per original script
                "OS version"         = "Error"
                "Manufacturer"       = "Error"
                "Model"              = "Error"
                "Serial number"      = "Error"
                "Primary user UPN"   = "Error"
                "Enrolled By UPN"    = "Error"
                "Wired IPv4 Addresses" = "Error"
                "IP Address V4"      = "Error"
                "Subnet Address"     = "Error"
                "Intune Device ID"   = "Error"
                "Azure AD Device ID" = "Error" # Was Intune's AAD ID
                "AAD ID from Group"  = $azureAdDeviceId
                "Management State"   = "Error"
                "Last Sync"          = "Error"
                "Additional Detail Error" = "Main Get-MgDevice error"
            }
            $csvData.Add($deviceObject)
        }
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
    if (-not $scriptPath) { $scriptPath = Get-Location } # Fallback to current directory
    $csvPath = Join-Path -Path $scriptPath -ChildPath $csvFileName
    
    try {
        $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Output "`n-----------------------------------------------------------------`n"
        Write-Output "Device report successfully exported to: $csvPath" -ForegroundColor Green
        Write-Output "Total Azure AD devices in group processed: $($groupDevicesResponse.value.Count)"
        Write-Output "Total records in CSV: $($csvData.Count)"
        Write-Output "-----------------------------------------------------------------`n"
    }
    catch {
        $exportErrorMessage = $_.Exception.Message
        Write-Error "Failed to export CSV data to '$csvPath'. Error: $exportErrorMessage"
    }
} else {
    Write-Output "`nNo data to export to CSV for group '$groupDisplayNameForReport'."
}

# Disconnect-MgGraph # Optional: uncomment if you want to explicitly disconnect