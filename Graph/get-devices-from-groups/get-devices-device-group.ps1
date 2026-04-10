Connect-MgGraph -Scopes "User.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All", "Directory.ReadWrite.All"

$groupId = ""

$devicesUri = "https://graph.microsoft.com/v1.0/groups/$groupId/members`?`$select=id&`$top=999"

$continue = $true
$csvData = @()

while ($continue) {
    $groupDevicesResponse = Invoke-MgGraphRequest -Uri $devicesUri -Method GET -OutputType PSObject

    if ($null -eq $groupDevicesResponse.value -or $groupDevicesResponse.value.Count -eq 0) {
        Write-Output "No more devices found in the group or failed to fetch devices."
        $continue = $false
    } else {
        foreach ($device in $groupDevicesResponse.value) {
            $deviceID = $device.id
            Write-Host "Device ID: $deviceID added"

            try {
                $selectString= "id,displayName,operatingSystem,operatingSystemVersion,manufacturer,model,serialNumber"  
                $deviceDetailUri = "https://graph.microsoft.com/v1.0/devices/$deviceID`?`$select=$selectString"
                $deviceResponse = Invoke-MgGraphRequest -Uri $deviceDetailUri -Method GET -OutputType PSObject

                $deviceObject = [PSCustomObject]@{
                    "Device ID" = $deviceResponse.id
                    "Device name" = $deviceResponse.displayName
                    "OS" = $deviceResponse.operatingSystem
                    "OS version" = $deviceResponse.operatingSystemVersion
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

        # checks for next link to continue 
        if ($groupDevicesResponse.'@odata.nextLink') {
            $devicesUri = $groupDevicesResponse.'@odata.nextLink'
        } else {
            $continue = $false
        }
    }
}

$currentDate = Get-Date -Format "MM-dd-yyyy"
$csvPath = "managed_devices_report_$currentDate.csv"
$csvData | Export-Csv -Path $csvPath -NoTypeInformation
Write-Output "Device report generated at $csvPath"
