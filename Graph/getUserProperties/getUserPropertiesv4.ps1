Connect-MgGraph -Scopes "User.Read.All"  

$userIds = Import-Csv -Path "./Users.csv"
$totalUsers = $userIds.Count
$currentCount = 0

$results = @()

foreach ($user in $userIds) {
    $currentCount++  
    $userId = $user.userId
    Write-Host "Processing user: $userId ($currentCount of $totalUsers)"

    $userPrincipalName = "Not Found"  # default value if the email is not found
    $officeLocation = "Not Found"  # default value if the office location is not found
    $onPremisesDistinguishedName = "Not Found" # default value if the DN is not found

    $selectProperties = "userPrincipalName,officeLocation,onPremisesDistinguishedName"
    $apiURL = "https://graph.microsoft.com/v1.0/users/$userId`?`$select=$selectProperties"
    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject
        if ($response) {
            $userPrincipalName = $response.userPrincipalName
            $officeLocation = $response.officeLocation
            $onPremisesDistinguishedName = $response.onPremisesDistinguishedName
        } else {
            Write-Host "No data returned for user: $userId"
        }
    } catch {
        Write-Error "Failed to fetch data for user $userId"
    }

    $results += [PSCustomObject]@{
        UserId = $userId
        UserEmail = $userPrincipalName
        OfficeLocation = $officeLocation
        OnPremisesDistinguishedName = $onPremisesDistinguishedName
    }
}

# Export results to CSV
$results | Export-Csv -Path "./userDetails.csv" -NoTypeInformation
