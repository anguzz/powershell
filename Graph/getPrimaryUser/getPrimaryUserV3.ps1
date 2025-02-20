

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
            Write-Host "Primary user email for device $DeviceId $($user.UserPrincipalName)"
            return $user.UserPrincipalName
        } else {
            Write-Host "No users found associated with the device ID: $DeviceId"
            return $null
        }
    } catch {
        Write-Host "Error: $_"
        return $null
    }
}

# Path to your CSV file; must include a "DisplayName" column (or adjust as needed).
$csvFilePath = "./devices.csv"
$outputFilePath = "./PrimaryUsers.csv"

# Import the CSV and iterate over each row
$devices = Import-Csv -Path $csvFilePath
$results = foreach ($entry in $devices) {
    $displayName = $entry.DisplayName

    Write-Host "`nProcessing device display name: $displayName"

    $deviceId = Get-DeviceIdByDisplayName -DisplayName $displayName
    if ($deviceId) {
        $email = Get-PrimaryUserEmailByDeviceId -DeviceId $deviceId
        if ($email) {
            [PSCustomObject]@{
                DisplayName = $displayName
                DeviceId = $deviceId
                Email = $email
            }
        }
    } else {
        Write-Host "No device found for display name: $displayName"
    }
}

# Export results to CSV
$results | Export-Csv -Path $outputFilePath -NoTypeInformation
