
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"
$managedDeviceId = " 12345678-1234-1234-1234-1234567890ab"

$apiURL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$managedDeviceId"

Invoke-MgGraphRequest -Method GET $apiURL 


#gets the hardware config from a device
