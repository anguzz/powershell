#showcase of how to add a devices display name to a group to an entra group

Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"
function Add-DeviceToGroup {
    param(
        [string]$GroupId,
        [string]$DeviceId
    )

    $params = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$DeviceId"
    }

    try {
        New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $params
        Write-Host "Device added to group: $DeviceId"
        $true
    } catch {
        Write-Host "Failed to add device to group: $_"
        $false
    }
}

function Get-DeviceIdByDisplayName {
    param(
        [string]$DisplayName
    )

    $device = Get-MgDevice -Filter "displayName eq '$DisplayName'" -Top 1
    return $device.Id
}

$DisplayName = "" #name of the device as seen on intune/entra admin portal 
$GroupId = "" #group id 
$DeviceId = Get-DeviceIdByDisplayName -DisplayName $DisplayName

if ($DeviceId) {
    $result = Add-DeviceToGroup -GroupId $GroupId -DeviceId $DeviceId
    if (-not $result) {
        Write-Host "Error adding device by display name to group"
    }
} else {
    Write-Host "Device ID not found for display name: $DisplayName"
}
