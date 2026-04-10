



$TenantId = ""

$OutputCsvPath = "./DiscovredTargetAppsDevices.csv"

# add your target applications here
# Note: The script will only search for the display name of the app, not the version or other properties.
$TargetAppNames = @(
    #"Chrome",
    #"Edge",

)


Write-Host "Connecting to Microsoft Graph..."

try {
    if ($TenantId) {
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementApps.ReadWrite.All" -NoWelcome -TenantId $TenantId
    } else {
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All", "DeviceManagementApps.ReadWrite.All" -NoWelcome
    }
    Write-Host "Successfully connected to Graph."
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    return # Stop script if connection fails
}

Write-Host "`n`n"

Write-Host "Target Applications: $($TargetAppNames -join ', ')" 

Write-Host "`n`n"

Write-Host "Output File: '$OutputCsvPath'"

$allFoundResults = @()
$uniqueAppInstanceIds = @{} 

foreach ($appName in $TargetAppNames) {

    Write-Host "--------------------------------------------------"
    Write-Host "Searching for detected instances of '$appName'..."
    $filter = "displayName eq '$appName'"
    $detectedAppsUri = "https://graph.microsoft.com/beta/deviceManagement/detectedApps?`$filter=$($filter)&`$select=id,displayName,version,platform,publisher"
    $matchingAppInstances = @() # Instances matching the CURRENT appName

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $detectedAppsUri -OutputType PSObject
        if ($response -ne $null) {
            $matchingAppInstances += $response.value
            $nextLink = $response.'@odata.nextLink'

            while ($null -ne $nextLink) {
                Write-Host "Fetching next page of matching app instances for '$appName'..."
                $response = Invoke-MgGraphRequest -Uri $nextLink -Method GET -OutputType PSObject
                if ($response -ne $null) {
                    $matchingAppInstances += $response.value
                    $nextLink = $response.'@odata.nextLink'
                } else {
                    Write-Warning "Received null response while paginating matching apps for '$appName'."
                    $nextLink = $null # Exit loop
                }
            }
        }

    } catch {
        Write-Warning "Failed to retrieve detected applications for '$appName': $($_.Exception.Message)"
        continue
    }

    if ($matchingAppInstances.Count -eq 0) {
        Write-Host "No detected instances found matching the display name '$appName'."
        continue
    }

    Write-Host "Found $($matchingAppInstances.Count) detected instance(s) matching '$appName'. Adding them to the list for device retrieval."

    foreach ($appInstance in $matchingAppInstances) {
        if (-not $appInstance.version -or [string]::IsNullOrWhiteSpace($appInstance.version)) {
           Write-Warning "Skipping instance ID $($appInstance.id) for '$($appInstance.displayName)' due to missing version."
           continue
        }
        if (-not $uniqueAppInstanceIds.ContainsKey($appInstance.id)) {
            $uniqueAppInstanceIds[$appInstance.id] = @{
                AppName    = $appInstance.displayName
                Version    = $appInstance.version.Trim()
                Platform   = $appInstance.platform
                Publisher  = $appInstance.publisher
            }
        }
    }
    Write-Host "Total unique application instances to check for devices so far: $($uniqueAppInstanceIds.Count)"

} 

Write-Host "--------------------------------------------------"

if ($uniqueAppInstanceIds.Count -eq 0) {
    Write-Host "No instances of any target applications found across the environment."
    return
}

Write-Host "Retrieving associated devices for $($uniqueAppInstanceIds.Count) unique application instances found..."

$processedAppInstanceCount = 0
foreach ($appInstanceId in $uniqueAppInstanceIds.Keys) {
    $processedAppInstanceCount++
    $appInfo = $uniqueAppInstanceIds[$appInstanceId]
    Write-Host "[$processedAppInstanceCount/$($uniqueAppInstanceIds.Count)] Getting devices for '$($appInfo.AppName)' version '$($appInfo.Version)' (ID: $appInstanceId)..."

    $devicesUri = "https://graph.microsoft.com/beta/deviceManagement/detectedApps/$appInstanceId/managedDevices?`$select=id,deviceName,userPrincipalName,managedDeviceOwnerType,complianceState,osVersion"
    $devicesForApp = @()

    try {
        $devResponse = Invoke-MgGraphRequest -Method GET -Uri $devicesUri -OutputType PSObject
        if ($devResponse -ne $null) {
            $devicesForApp += $devResponse.value
            $devNextLink = $devResponse.'@odata.nextLink'

            while ($null -ne $devNextLink) {
                Write-Host "Fetching next page of devices for app ID $appInstanceId..."
                $devResponse = Invoke-MgGraphRequest -Uri $devNextLink -Method GET -OutputType PSObject
                 if ($devResponse -ne $null) {
                    $devicesForApp += $devResponse.value
                    $devNextLink = $devResponse.'@odata.nextLink'
                } else {
                     Write-Warning "Received null response while paginating devices for app ID $appInstanceId."
                    $devNextLink = $null
                }
            }
         } 

    } catch {
        Write-Warning "Failed to retrieve devices for App ID '$appInstanceId' ('$($appInfo.AppName)' v$($appInfo.Version)): $($_.Exception.Message)"
        continue
    }


    foreach ($device in $devicesForApp) {
        $allFoundResults += [PSCustomObject]@{
            DeviceName           = $device.deviceName
            PrimaryUserUPN       = $device.userPrincipalName
            DeviceId             = $device.id
            DetectedApp          = $appInfo.AppName 
            DetectedVersion      = $appInfo.Version
            AppPlatform          = $appInfo.Platform
            AppPublisher         = $appInfo.Publisher
            OSVersion            = $device.osVersion
            Ownership            = $device.managedDeviceOwnerType
            DeviceCompliance     = $device.complianceState
        }
    }
     Write-Host "...found on $($devicesForApp.Count) devices."

} 

Write-Host "--------------------------------------------------"

if ($allFoundResults.Count -gt 0) {
    Write-Host "Exporting $($allFoundResults.Count) records of detected applications to '$OutputCsvPath'..."
    try {
        $OutputCsvDir = Split-Path -Path $OutputCsvPath -Parent
        if (-not (Test-Path $OutputCsvDir)) {
            Write-Host "Creating output directory: $OutputCsvDir"
            New-Item -ItemType Directory -Path $OutputCsvDir -Force | Out-Null
        }
        $allFoundResults | Sort-Object -Property DetectedApp, DeviceName | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Export complete: $OutputCsvPath"
    } catch {
        Write-Error "Failed to export results to CSV '$OutputCsvPath': $($_.Exception.Message)"
    }
} else {
    Write-Host "No devices found running any instances of the specified target applications."
}

# Disconnect-MgGraph

Write-Host "Script finished."