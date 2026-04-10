
$scopes = "DeviceManagementManagedDevices.ReadWrite.All" 

try {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes $scopes
    Write-Host "Successfully connected."
}
catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    return
}

$apiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,userPrincipalName,operatingSystem,osVersion&`$top=999" # Request max page size

$allManagedDevices = @() 

Write-Host "Fetching devices..."
do {
    try {
        Write-Host "Requesting data from: $apiUrl"
        $response = Invoke-MgGraphRequest -Method GET -Uri $apiUrl -OutputType PSObject -ErrorAction Stop

        if ($response -is [PSCustomObject] -and $response.PSObject.Properties.Name -contains 'value') {
             Write-Host "Retrieved $($response.value.Count) devices on this page."
             $allManagedDevices += $response.value 
             $apiUrl = $response.'@odata.nextLink' 
        } elseif ($response -is [array]) {
            # handle cases where the response might be the array directly (less common for paged results)
             Write-Host "Retrieved $($response.Count) devices on this page (direct array response)."
             $allManagedDevices += $response
             $apiUrl = $null 
        } else {
             Write-Warning "Unexpected response format received for URL: $apiUrl"
             Write-Warning ($response | Out-String)
             $apiUrl = $null 
        }

    }
    catch {
        Write-Error "Error during Graph API request to '$apiUrl': $($_.Exception.Message)"
        $apiUrl = $null # this will stop the pagination on error
    }

} while ($apiUrl -ne $null -and $apiUrl -ne "") 

Write-Host "Total devices fetched across all pages: $($allManagedDevices.Count)"

Write-Host "Filtering for devices with no primary user..."
$devicesWithNoPrimaryUser = $allManagedDevices | Where-Object { $null -eq $_.userPrincipalName -or "" -eq $_.userPrincipalName }
Write-Host "Found $($devicesWithNoPrimaryUser.Count) devices with no primary user."

$results = @()
foreach ($device in $devicesWithNoPrimaryUser) {
    $results += [PSCustomObject]@{
        DeviceId          = $device.id
        DeviceName        = $device.deviceName
        UserPrincipalName = $device.userPrincipalName 
        operatingSystem = $device.operatingSystem 
        osVersion = $device.osVersion
    }
}

if ($results.Count -gt 0) {
    $filePath = ".\Devices_With_No_PrimaryUser.csv" 
    try {
        $results | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Host "Successfully exported $($results.Count) devices with no primary user (null or empty UPN) to $filePath"
    }
    catch {
        Write-Error "Failed to export CSV file to '$filePath': $($_.Exception.Message)"
    }
} else {
    Write-Host "No devices with a null or empty primary user were found to export."
}

Write-Host "Disconnecting from Microsoft Graph..."
Disconnect-MgGraph 