
param(
    [Parameter(Mandatory=$true)]
    [string]$GroupId
)
Connect-MgGraph -Scopes "User.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "Directory.ReadWrite.All"

$connection = Get-MgContext
if (-not $connection) {
    Write-Warning "Not connected to Microsoft Graph. Please connect using Connect-MgGraph."
    
    return
} else {
    Write-Host "Connected to tenant $($connection.TenantId) as $($connection.Account)"
}

Write-Host "`nFetching group information..."
try {
    $group = Get-MgGroup -GroupId $GroupId -Property Id, DisplayName -ErrorAction Stop
    $groupDisplayName = $group.DisplayName
    Write-Host "Target Group: $groupDisplayName (ID: $GroupId)"
} catch {
    Write-Error "Failed to fetch group information for ID '$GroupId'. Error: $($_.Exception.Message)"
    return
}

Write-Host "`nFetching members of group '$groupDisplayName'..."
$groupMembers = @{} 
$uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/members?`$select=id,userPrincipalName&`$top=999"


$memberCount = 0
while ($uri) {
    try {
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET
        if ($null -ne $response.value) {
            foreach ($member in $response.value) {
                if ($member.'@odata.type' -eq '#microsoft.graph.user') {
                    if (-not $groupMembers.ContainsKey($member.id)) {
                        $groupMembers.Add($member.id, $member.userPrincipalName)
                        $memberCount++
                    }
                } else {
                    Write-Warning "Skipping non-user member: $($member.id) ($($member.'@odata.type'))"
                }
            }
            $uri = $response.'@odata.nextLink'
            if ($uri) { Write-Host "Fetching next page of group members..." }
        } else {
            $uri = $null 
        }
    } catch {
        Write-Error "Failed to fetch group members. URI: $uri. Error: $($_.Exception.Message)"
        $uri = $null 
    }
}

if ($groupMembers.Count -eq 0) {
    Write-Host "No user members found in the group '$groupDisplayName'."
    return
} else {
    Write-Host "Found $($groupMembers.Count) user members in group '$groupDisplayName'."
}


Write-Host "`nFetching all managed devices (this may take time for large tenants)..."
$csvData = New-Object System.Collections.Generic.List[Object]
$deviceCount = 0
$processedDeviceCount = 0

$deviceSelectProperties = "id,deviceName,serialNumber,usersLoggedOn,osVersion,complianceState,managementAgent,managedDeviceOwnerType,azureADDeviceId,userPrincipalName,operatingSystem,manufacturer,model,lastSyncDateTime"
$devicesUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$select=$deviceSelectProperties&`$top=100"

while ($devicesUri) {
    Write-Host "Fetching devices batch..."
    try {
        $deviceResponse = Invoke-MgGraphRequest -Uri $devicesUri -Method GET
        if ($null -ne $deviceResponse.value) {
            $processedDeviceCount += $deviceResponse.value.Count
            Write-Host "Processing $($deviceResponse.value.Count) devices... (Total Processed: $processedDeviceCount)"

            foreach ($device in $deviceResponse.value) {
                if ($null -ne $device.usersLoggedOn) {
                    foreach ($loggedOnUser in $device.usersLoggedOn) {
                        if ($groupMembers.ContainsKey($loggedOnUser.userId)) {
                            $foundUserUPN = $groupMembers[$loggedOnUser.userId]
                            Write-Verbose "Match found: User '$foundUserUPN' logged onto device '$($device.deviceName)'"
                            $lastLogonTime = $loggedOnUser.lastLogOnDateTime


                            $deviceObject = [PSCustomObject]@{
                                "GroupMemberUPN_LoggedOn" = $foundUserUPN 
                                "GroupMember_LastLogonTime" = $lastLogonTime
                                "Device Name"             = $device.deviceName
                                "Device ID"               = $device.id
                                "OS"                      = $device.operatingSystem
                                "OS Version"              = $device.osVersion
                                "Serial Number"           = $device.serialNumber
                                "Compliance State"        = $device.complianceState
                                "Managed By"              = $device.managementAgent
                                "Ownership"               = $device.managedDeviceOwnerType
                                "Azure AD Device ID"      = $device.azureADDeviceId
                                "Primary User UPN"        = $device.userPrincipalName 
                                "Manufacturer"            = $device.manufacturer
                                "Model"                   = $device.model
                                "Last Sync"               = $device.lastSyncDateTime
                            }
                            $csvData.Add($deviceObject)
                            $deviceCount++
                        }
                    }
                }
            }

            $devicesUri = $deviceResponse.'@odata.nextLink'
        } else {
            $devicesUri = $null 
        }
    } catch {
        Write-Error "Failed to fetch devices. URI: $devicesUri. Error: $($_.Exception.Message)"
        $devicesUri = $null 
    }
}

Write-Host "`n-----------------------------------------------------------------`n"
if ($csvData.Count -gt 0) {
    Write-Host "Found $deviceCount instances of group members logged onto devices."
    $currentDate = Get-Date -Format "yyyyMMdd"
    $csvPath = "LoggedOnDevices_Group_$($groupDisplayName -replace '[^a-zA-Z0-9]','_')_$currentDate.csv" 
    Write-Host "Exporting report to $csvPath"
    $csvData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "Report generation complete."
} else {
    Write-Host "No devices found where members of group '$groupDisplayName' have logged on."
}
Write-Host "`n-----------------------------------------------------------------`n"