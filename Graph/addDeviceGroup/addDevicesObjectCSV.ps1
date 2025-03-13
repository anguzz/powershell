Import-Module Microsoft.Graph.Groups

Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

$GroupId = ""

$deviceIds = Import-Csv -Path "./deviceIds.csv"


foreach ($device in $deviceIds) {
    $params = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($device.DeviceId)"
    }| ConvertTo-Json -Depth 1

    try {
        New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $params -ErrorAction Stop
        Write-Host "Device $($device.DeviceId) added successfully to group $GroupId."
    } catch {
        Write-Host "Error adding device $($device.DeviceId) to group: $_"
    }
}
