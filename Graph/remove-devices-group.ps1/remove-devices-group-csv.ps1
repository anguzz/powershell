# Removes a list of devices from an Entra group based on their hostnames in a CSV
# CSV format: DeviceName (column header)

Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

$GroupId = "" # add entra device group ID here
$csvPath = Join-Path -Path $PSScriptRoot -ChildPath "devices.csv"
$devices = Import-Csv -Path $csvPath

$groupDisplayNameURL = "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=displayName"
$groupDisplayResponse = Invoke-MgGraphRequest -Uri $groupDisplayNameURL -Method GET -OutputType PSObject
$groupDisplayName = $groupDisplayResponse.displayName

Write-Output "`n-----------------------------------------------------------------`n"
Write-Output "Beginning device removal from group: $groupDisplayName"
Write-Output "Total devices to process: $($devices.Count)"
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
        Write-Warning "Error retrieving device '$DisplayName': $($_.Exception.Message)"
        return $null
    }
}

function Remove-DeviceFromGroup {
    param(
        [string]$GroupId,
        [string]$DeviceId
    )

    try {
        Remove-MgGroupMemberByRef -GroupId $GroupId -DirectoryObjectId $DeviceId -ErrorAction Stop
        Write-Host "Device removed from group: $DeviceId"
        return $true
    } catch {
        Write-Host "Failed to remove device: $($_.Exception.Message)"
        return $false
    }
}

$row = 1
foreach ($device in $devices) {
    $DeviceId = Get-DeviceIdByDisplayName -DisplayName $device.DeviceName

    if ($DeviceId) {
        $result = Remove-DeviceFromGroup -GroupId $GroupId -DeviceId $DeviceId
        if (-not $result) {
            Write-Host "Error removing device $($device.DeviceName) from group"
        }
    } else {
        Write-Host "Device ID not found for display name: $($device.DeviceName)"
    }

    Write-Output "Device $row out of $($devices.Count): $($device.DeviceName) processed"
    Write-Output "`n-----------------------------------------------------------------`n"
    $row++
}
