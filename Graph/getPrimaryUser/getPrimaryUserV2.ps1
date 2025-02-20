#gets the primary user based off device display name


Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

function Get-DeviceIdByDisplayName {
    param(
        [string]$DisplayName
    )

    $device = Get-MgDevice -Filter "displayName eq '$DisplayName'" -Top 1
    return $device.Id
}

function Get-PrimaryUserEmailByDeviceId {
    param(
        [string]$DeviceId
    )

    try {
        $registeredOwners = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/devices/$DeviceId/registeredOwners" -ErrorAction Stop
        if ($registeredOwners.value -and $registeredOwners.value.Count -gt 0) {
            $primaryUserId = $registeredOwners.value[0].id

            $user = Get-MgUser -UserId $primaryUserId -ErrorAction Stop
            Write-Host "Primary user email: $($user.UserPrincipalName)"
        } else {
            Write-Host "No users found associated with the device ID: $DeviceId"
        }
    } catch {
        Write-Host "Error: $_"
    }
}

$DisplayName = "" # displayname goes here
$DeviceId = Get-DeviceIdByDisplayName -DisplayName $DisplayName

if ($DeviceId) {
    Get-PrimaryUserEmailByDeviceId -DeviceId $DeviceId
} else {
    Write-Host "Device ID not found for display name: $DisplayName"
}