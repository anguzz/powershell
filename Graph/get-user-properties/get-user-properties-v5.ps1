Connect-MgGraph -Scopes "User.Read.All"

$users = Import-Csv -Path "./Users.csv"

$results = @()

foreach ($user in $users) {
    $userId = $user.userID
    Write-Host "Processing: $userId"  # Using userID for visibility as userEmail is not defined

    $apiURL = "https://graph.microsoft.com/v1.0/users/$userId"

    $email = "Not Found"  # Default value if email is not found
    $officeLocation = "Not Found"  # Default value if location is not found

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject
        if ($response) {
            if ($response.mail) {
                $email = $response.mail
            }
         
        }
    } catch {
        Write-Error "Failed to fetch data for userID: $userId"
    }

    $results += [PSCustomObject]@{
        UserID = $userId
        Email = $email
    }
}

$results | Export-Csv -Path "./userEmails.csv" -NoTypeInformation
Write-Host "Output file created: ./userEmails.csv"
