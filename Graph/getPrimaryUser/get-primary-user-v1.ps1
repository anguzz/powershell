Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All"



$DeviceId = "1023fb41-d032-453e-b5b2-4fbc8ca460ae"#add device ID here

try {
    $registeredOwners = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/devices/$DeviceId/registeredOwners" -ErrorAction Stop

    if ($registeredOwners.value -and $registeredOwners.value.Count -gt 0) {
        $primaryUserId = $registeredOwners.value[0].id

        $user = Get-MgUser -UserId $primaryUserId -ErrorAction Stop
        Write-Host "Primary user email: $($user.UserPrincipalName)"
    } else {
        Write-Host "No users found associated with the device ID: $DeviceId"
    }
}
catch {
    Write-Host "Error: $_"
}
