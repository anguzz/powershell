#this script gets devices in a device group, without users. 


Connect-MgGraph -Scopes "User.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "Directory.ReadWrite.All"

$groupId = ""

# fetch devices within the group
$devicesUri = "https://graph.microsoft.com/v1.0/groups/$groupId/members`?`$select=id"
$groupDevicesResponse = Invoke-MgGraphRequest -Uri $devicesUri -Method GET -OutputType PSObject

Write-Output "`n-----------------------------------------------------------------`n"

$groupDisplayNameURL = "https://graph.microsoft.com/v1.0/groups/$groupId`?`$select=displayName"
$groupDisplayResponse = Invoke-MgGraphRequest -Uri $groupDisplayNameURL -Method GET -OutputType PSObject
$groupDisplayName = $groupDisplayResponse.displayName

Write-Output "Starting device report for " $groupDisplayName

Write-Output "`n-----------------------------------------------------------------`n"
$csvData = @()

if ($null -eq $groupDevicesResponse.value -or $groupDevicesResponse.value.Count -eq 0) {
    Write-Output "No devices found in the group or failed to fetch devices."
    return
} else {
    foreach ($device in $groupDevicesResponse.value) {
        $deviceID = $device.id
        try {
            $deviceDetailUri = "https://graph.microsoft.com/v1.0/devices/$deviceID`?`$select=id,displayName,operatingSystem,manufacturer,model,serialNumber"
            $deviceResponse = Invoke-MgGraphRequest -Uri $deviceDetailUri -Method GET -OutputType PSObject

            $deviceObject = [PSCustomObject]@{
                "Device ID" = $deviceResponse.id
                "Device name" = $deviceResponse.displayName
                "OS" = $deviceResponse.operatingSystem
                "Manufacturer" = $deviceResponse.manufacturer
                "Model" = $deviceResponse.model
                "Serial number" = $deviceResponse.serialNumber
                "Primary user" = $deviceResponse.Primary
            }
            $csvData += $deviceObject

        } catch {
            Write-Output "Failed to fetch details for device ID $deviceID $($_.Exception.Message)"
        }
    }
}

$currentDate = Get-Date -Format "MM-dd-yyyy"
$csvPath = "managed_devices_report_$currentDate.csv"
$csvData | Export-Csv -Path $csvPath -NoTypeInformation
Write-Output "Device report generated at $csvPath"
