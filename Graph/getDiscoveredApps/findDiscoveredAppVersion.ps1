#gets all devices with less then a target version and puts in csv file, for example if you everything under 2.0 make that your version threshhold 

Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","DeviceManagementApps.ReadWrite.All"


$filter = "displayName eq 'App Name'"  #change app name to what app display name you are targetting
$versionThreshold = [Version]"2.0"  # filters the app entries to find versions below current targetted version 2.0, adjust accordingly


$encodedFilter = [System.Uri]::EscapeDataString($filter)  # Encodes the filter for use in URL
$detectedAppsUri = "https://graph.microsoft.com/v1.0/deviceManagement/detectedApps?`$filter=$encodedFilter"
$response = Invoke-MgGraphRequest -Method GET -Uri $detectedAppsUri
$targetApps = $response.value  # parse/extract detectedApp objects from the response



$outdatedApps = $targetApps | Where-Object {
    try {
        [Version]$_.version -lt $versionThreshold   #this line would have to be changed if you want to target a different version or change criteria
    }
    catch {
        $false
    }
}


# now get device id per bad version found.
$results = @()  
foreach ($app in $outdatedApps) {
    $appId = $app.id
    $appVersion = $app.version
    $appName = $app.displayName
    # this API call to is to list managed devices for this detected app 
    $devicesUri = "https://graph.microsoft.com/v1.0/deviceManagement/detectedApps/$appId/managedDevices?"
    $deviceResponse = Invoke-MgGraphRequest -Method GET -Uri $devicesUri
    $managedDevices = $deviceResponse.value
    # now we loop through the devices with the detected app and look at the properties
    foreach ($device in $managedDevices) {
        $results += [PSCustomObject]@{
            DeviceId          = $device.id           
            AppDisplayName    = $appName           
            DetectedAppVersion= $appVersion        
        }
    }
 
}


$results | Export-Csv -Path ".\AppOutdatedDevices.csv" -NoTypeInformation

Write-Host "Exported $(($results).Count) records to AppOutdatedDevices.csv"
