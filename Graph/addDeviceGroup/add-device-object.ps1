Import-Module Microsoft.Graph.Groups

Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"


$GroupId = "" # entra group id  
$DeviceId = "" #entra object ID on entra admin portal

$params = @{
    "@odata.id" = "https://graph.microsoft.com/beta/devices/$DeviceId"
}

try {
    New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $params -ErrorAction Stop
    Write-Host "Device added successfully."
}
catch {
    Write-Host "Error adding device to group: $_"
}
