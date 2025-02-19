#simple showcase of how to add an object(device) to a group on entra

Import-Module Microsoft.Graph.Groups

Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

#pass in device/group ids here 
#easily  found on entra portal in the url 
$GroupId = ""  
$DeviceId = "" 


$params = @{
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$DeviceId"
}

try {
    New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $params -ErrorAction Stop
    Write-Host "Device added successfully."
}
catch {
    Write-Host "Error adding device to group: $_"
}
