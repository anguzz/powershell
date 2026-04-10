#adds a list of devices in a csv by their host name to an entra group
#see devices.csv for format


Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

$GroupId = "" #add group id from entra here
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "devices.csv" #change to appropiate file name,
$devices = Import-Csv -Path $csvPath


$groupDisplayNameURL = "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=displayName"
$groupDisplayResponse = Invoke-MgGraphRequest -Uri $groupDisplayNameURL -Method GET -OutputType PSObject
$groupDisplayName = $groupDisplayResponse.displayName

Write-Output "`n-----------------------------------------------------------------`n"

Write-Output "Beginning device onboarding to " $groupDisplayName
Write-Output "Total devices to onboard: " $($devices.Count)
Write-Output "`n-----------------------------------------------------------------`n"


function Get-DeviceIdByDisplayName {
    param(
        [string]$DisplayName
    )

    Write-Host "`nAttempting to find device with display name: $DisplayName" 

    try {
        $device = Get-MgDevice -Filter "displayName eq '$DisplayName'" -Top 1 -ErrorAction Stop

        if ($device) {
            Write-Host "Device id found: $($device.Id)"
            return $device.Id 
        } else {
            Write-Host "No device found with display name: $DisplayName"
            return $null
        }
    } catch {
        Write-Warning "Error retrieving device with display name '$DisplayName': $($_.Exception.Message)"
        return $null
    }
}

function Add-DeviceToGroup {
    param(
        [string]$GroupId,
        [string]$DeviceId
    )

    $deviceUrl = "https://graph.microsoft.com/v1.0/directoryObjects/$DeviceId"

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



$row = 1

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

    $row++
    Write-Output "Device $row out of $($devices.Count): $($device.DeviceName) processed"
    Write-Output "`n-----------------------------------------------------------------`n"
}
