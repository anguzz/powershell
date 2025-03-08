Connect-MgGraph -Scopes "User.Read.All"

$users = Import-Csv -Path "./userEmails.csv"

$results = @()

foreach ($user in $users) {
    $userEmail = $user.emailAddress
    Write-Host "Processing: $userEmail" 

    $apiURL = "https://graph.microsoft.com/v1.0/users/$userEmail"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject
        $email = $response.mail
        $officeLocation = $response.officeLocation

        $results += [PSCustomObject]@{
            Email = $email
            OfficeLocation = $officeLocation
        }
    } catch {
        Write-Error "Failed to fetch data for $userEmail"
    }
}

$results | Export-Csv -Path "./userOffices.csv" -NoTypeInformation
