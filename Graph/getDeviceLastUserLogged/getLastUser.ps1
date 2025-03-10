Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"

$deviceIds = Import-Csv -Path "./devices.csv"

$results = @()

foreach ($device in $deviceIds) {
    $deviceId = $device.deviceId
    Write-Host "Processing device: $deviceId"  

    $userId = "Not Found"  # default value if the user ID is not found
    $lastLogonDateTime = "Not Found"  # default value if the logon date/time is not found

    $selectProperties = "usersLoggedOn"
    $apiURL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId`?`$select=$selectProperties"
    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject
        if ($response -and $response.usersLoggedOn -and $response.usersLoggedOn.Count -gt 0) {
            # Only take the first logged on user, otherwise will get all users per device and make multiple entries
            #remove [0] if you want all users on the device, expands the data
            $userId = $response.usersLoggedOn[0].userId
            $lastLogonDateTime = $response.usersLoggedOn[0].lastLogonDateTime
        } else {
            Write-Host "No logged on users data returned for device: $deviceId"
        }
    } catch {
        Write-Error "Failed to fetch data for device $deviceId"
    }

    $results += [PSCustomObject]@{
        DeviceId = $deviceId
        UserId = $userId
        LastLogonDateTime = $lastLogonDateTime
    }
}

# Export results to CSV
$results | Export-Csv -Path "./deviceLogons.csv" -NoTypeInformation
