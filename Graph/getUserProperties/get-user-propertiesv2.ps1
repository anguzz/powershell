Connect-MgGraph -Scopes "User.Read.All"

$users = Import-Csv -Path "./userEmails.csv"

$results = @()

foreach ($user in $users) {
    $userEmail = $user.emailAddress
    Write-Host "Processing: $userEmail"  #  for visibility

    $apiURL = "https://graph.microsoft.com/v1.0/users/$userEmail"

    $email = $userEmail  # use emailAddress from original sheet
    $officeLocation = "Not Found"  # add default value if the location is not found

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject
        if ($response -and $response.mail -and $response.officeLocation) {
            $email = $response.mail
            $officeLocation = $response.officeLocation
        }
    } catch {
        Write-Error "Failed to fetch data for $userEmail"
    }

    $results += [PSCustomObject]@{
        Email = $email
        OfficeLocation = $officeLocation
    }
}

$results | Export-Csv -Path "./userOffices.csv" -NoTypeInformation
