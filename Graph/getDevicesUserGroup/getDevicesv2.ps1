Connect-MgGraph -Scopes "User.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "Directory.ReadWrite.All"

$groupId = ""
$selectString = "userPrincipalName,id"
$uri = "https://graph.microsoft.com/v1.0/groups/$groupId/members`?`$select=$selectString"

$jsonResponse = Invoke-MgGraphRequest -Uri $uri -Method GET -OutputType json
$groupMembers = $jsonResponse | ConvertFrom-Json

$csvData = New-Object System.Collections.Generic.List[Object]

$groupDisplayNameURL = "https://graph.microsoft.com/v1.0/groups/$groupId`?`$select=displayName"
$groupDisplayResponse = Invoke-MgGraphRequest -Uri $groupDisplayNameURL -Method GET -OutputType PSObject
$groupDisplayName = $groupDisplayResponse.displayName

Write-Output "`n-----------------------------------------------------------------`n"

Write-Output "Starting device report for " $groupDisplayName

Write-Output "`n-----------------------------------------------------------------`n"


if ($null -eq $groupMembers.value -or $groupMembers.value.Count -eq 0) {
    Write-Host "No members found in the group or failed to fetch members."
    return
} else {
    foreach ($member in $groupMembers.value) {
        $userId = $member.id
        $userPrincipalName = $member.userPrincipalName
        Write-Host "User ID: $userId, UPN: $userPrincipalName"

        try {
            $devicesUri = "https://graph.microsoft.com/beta/users/$userId/managedDevices"
            $deviceResponse = Invoke-MgGraphRequest -Uri $devicesUri -Method GET -OutputType PSObject

            if ($null -ne $deviceResponse.value) {
                foreach ($device in $deviceResponse.value) {
                    
                    <# the reason for this section is that some of these response values are not included in the previous deviceURI endpoint, such as enrolledbyUserPrincipalName meaning we have to
                    query for those extra values against the device once we have the device id and add them #>
                    #######################################################################
                    $deviceEnrollUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)`?`$select=enrolledByUserPrincipalName"
                    $enrollResponse = Invoke-MgGraphRequest -Uri $deviceEnrollUri -Method GET -OutputType PSObject
                    $enrolledByUPN = "NA"
                    if ($null -ne $enrollResponse) {
                        $enrolledByUPN = $enrollResponse.enrolledByUserPrincipalName
                    }
                    #######################################################################    
                
                    $deviceObject = [PSCustomObject]@{
                        "Device ID" = $device.id
                        "Device name" = $device.deviceName
                        "Primary user UPN" = $userPrincipalName
                        "Enrolled by User Principal name" = $enrolledByUPN
                        "Azure AD Device ID"                       = $device.azureADDeviceId
                        "OS version"                               = $device.osVersion
                        "Azure AD registered"                      = $device.azureADRegistered
                       # "EAS activation ID"                        = $device.easDeviceId
                        "Serial number"                            = $device.serialNumber
                        "Manufacturer"                             = $device.manufacturer
                        "Model"                                    = $device.model
                        "EAS activated"                            = $device.easActivated
                       #"IMEI"                                     = $device.imei
                       # "Last EAS sync time"                       = $device.easActivationDateTime
                       # "EAS reason"                               = $device.exchangeAccessStateReason
                        #"EAS status"                               = $device.exchangeAccessState
                        #"Compliance grace period expiration"       = $device.complianceGracePeriodExpirationDateTime
                        "Security patch level"                     = $device.androidSecurityPatchLevel
                        "Wi-Fi MAC"                                = $device.wiFiMacAddress
                        #"MEID"                                     = $device.meid
                        #"Subscriber carrier"                       = $device.subscriberCarrier
                        "Total storage"                            = $device.totalStorageSpaceInBytes
                        "Free storage"                             = $device.freeStorageSpaceInBytes
                       # "Management name"                          = $device.managedDeviceName
                        "Category"                                 = $device.deviceCategoryDisplayName
                        "UserId"                                   = $device.userId
                       # "Primary user display name"                = $device.userDisplayName
                        "Compliance"                               = $device.complianceState
                        "Managed by"                               = $device.managementAgent
                        "Ownership"                                = $device.managedDeviceOwnerType
                        "Device state"                             = $device.deviceRegistrationState
                        "Intune registered"                        = $device.azureADRegistered
                        #"Supervised"                               = $device.isSupervised
                        "Encrypted"                                = $device.isEncrypted
                        "OS"                                       = $device.operatingSystem
                        "Management certificate expiration date"   = $device.managementCertificateExpirationDate
                        #"Hardware info"                             =$device.hardwareInformation.wiredIPv4Addresses # will not work to get nested info, need to handle this later somehow

                    }
                    $csvData.Add($deviceObject)
                }
            } else {
                Write-Host "No managed devices found for user $userPrincipalName."
            }
        } catch {
            Write-Host "Failed to fetch managed devices for user $userPrincipalName $($_.Exception.Message)"
        }
    }
}

# Continue with your script for exporting CSV or any other operations

$currentDate = Get-Date -Format "MM-dd-yyyy"

$csvPath = "managed_devices_report_$currentDate.csv"

$csvData | Export-Csv -Path $csvPath -NoTypeInformation

