#add many devices based off display name to a group on entra
#use the devices.csv file format
Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

function Get-DeviceIdByDisplayName {
    param(
        [string]$DisplayName
    )

    $device = Get-MgDevice -Filter "displayName eq '$DisplayName'" -Top 1
    if ($device) {
        return $device.Id
    } else {
        Write-Host "No device found with display name: $DisplayName"
        return $null
    }
}

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

$GroupId = "" 

$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "devices.csv"
$devices = Import-Csv -Path $csvPath

foreach ($device in $devices) {
    $DeviceId = Get-DeviceIdByDisplayName -DisplayName $device.DeviceName
    if ($DeviceId) {
        $result = Add-DeviceToGroup -GroupId $GroupId -DeviceId $DeviceId
        if (-not $result) {
            Write-Host "Error adding device $($device.DeviceName) to group"
        }
    } else {
        Write-Host "Device ID not found for display name: $($device.DeviceName)"
    }
}
