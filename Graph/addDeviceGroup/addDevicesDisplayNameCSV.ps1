#adds a list of devices in a csv by their host name to an entra group
#currently endpoint does not work
#see devices.csv for format


Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"


$GroupId = "" #add group id from entra here
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "devices.csv" #change to appropiate file name,
$devices = Import-Csv -Path $csvPath


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
        #this return code returns null if display name is not found 
        #in turn leads 
    }
}

function Add-DeviceToGroup {
    param(
        [string]$GroupId,
        [string]$DeviceId
    )

    $deviceUrl = "https://graph.microsoft.com/v1.0/directoryObjects/$DeviceId"
    Write-Host "Attempting to add device to group with URL: $deviceUrl"

    $params = @{
        "@odata.id" = $deviceUrl
    } | ConvertTo-Json -Depth 1

    try {
        New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $params
        Write-Host "Device added to group: $DeviceId"
        $true
    } catch {
        Write-Host "Failed to add device to group: $_"
        $false
    }
}



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
