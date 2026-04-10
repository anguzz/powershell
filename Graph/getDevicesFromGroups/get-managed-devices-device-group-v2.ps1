# simplifid version of getManagedDevicesDeviceGroupv1.ps1
$groupId = "" 
$csvData = @()

Connect-MgGraph -Scopes DeviceManagementManagedDevices.ReadWrite.All, Group.ReadWrite.All

$group = Get-MgGroup -GroupId $groupId
if (!$group) { throw "Group not found." }

$aadDevices = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members/microsoft.graph.device?`$select=id,displayName"

foreach ($aadDevice in $aadDevices.value) {
    if (!$aadDevice.displayName) { continue }

    $intuneDevices = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$($aadDevice.displayName)'"

    if ($intuneDevices) {
        foreach ($device in $intuneDevices) {
            $csvData += [PSCustomObject]@{
                "AAD Device Name"   = $aadDevice.displayName
                "Intune Device Name"= $device.deviceName
                "OS"                = $device.operatingSystem
                "OS version"        = $device.osVersion
                "Manufacturer"      = $device.manufacturer
                "Model"             = $device.model
                "Serial number"     = $device.serialNumber
                "Primary user UPN"  = $device.userPrincipalName
                "Intune Device ID"  = $device.Id
                "Azure AD Device ID"= $device.azureADDeviceId
                "Management State"  = $device.ManagementState
                "Last Sync"         = $device.LastSyncDateTime
            }
        }
    }
    else {
        $csvData += [PSCustomObject]@{
            "AAD Device Name"    = $aadDevice.displayName
            "Intune Device Name" = "Not intune managed"
            "OS"                 = "-"
            "OS version"         = "-"
            "Manufacturer"       = "-"
            "Model"              = "-"
            "Serial number"      = "-"
            "Primary user UPN"   = "-"
            "Intune Device ID"   = "-"
            "Azure AD Device ID" = $aadDevice.id
            "Management State"   = "Not Found"
            "Last Sync"          = "-"
        }
    }
}

if ($csvData) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $safeGroupName = ($group.displayName -replace '\W','_')
    $filename = "Intune_Devices_${safeGroupName}_$timestamp.csv"
    $csvData | Export-Csv -Path $filename -NoTypeInformation

    Write-Host "Exported device data to: $filename" -ForegroundColor Green
}
else {
    Write-Host "No device data found to export." -ForegroundColor Yellow
}

Disconnect-MgGraph