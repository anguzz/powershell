Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"
#gets a device by any of the values in its json body response 

$deviceName = ""
$apiURL = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices`?`$filter=deviceName eq '$deviceName'"
#https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=deviceName eq ''

$response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject

$response.value
