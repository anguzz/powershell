
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"
$DeviceId = ""#add device ID here
 
Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/devices/$DeviceId" -ErrorAction Stop
