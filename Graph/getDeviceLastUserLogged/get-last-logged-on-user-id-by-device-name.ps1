
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"

$deviceName = "" #add display name here

$apiURL = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$deviceName'&`$select=usersLoggedOn"

$response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject

$response.value




