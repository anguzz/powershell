Connect-MgGraph -Scopes "User.Read.All"

$users = Import-Csv -Path "./userEmails.csv"

$results = @()

foreach ($user in $users) {
    $userEmail = $user.emailAddress
    Write-Host "Processing: $userEmail"  # Added for visibility

    $email = $userEmail  
    $officeLocation = "Not Found"  # default value if the location is not found
    $onPremisesDN = "Not Found"  # default value if the DN is not found

    $selectProperties = "mail,officeLocation,onPremisesDistinguishedName"
    $apiURL = "https://graph.microsoft.com/v1.0/users/$userEmail`?`$select=$selectProperties"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject
        if ($response) {
            if ($response.mail) {
                $email = $response.mail
            }
            if ($response.officeLocation) {
                $officeLocation = $response.officeLocation
            }
            if ($response.onPremisesDistinguishedName) {
                $onPremisesDN = $response.onPremisesDistinguishedName
            }
        } else {
            Write-Host "No data returned for: $userEmail"
        }
    } catch {
        Write-Error "Failed to fetch data for $userEmail"
    }

    $results += [PSCustomObject]@{
        Email = $email
        OfficeLocation = $officeLocation
        OnPremisesDistinguishedName = $onPremisesDN
    }
}

# Export results to CSV
$results | Export-Csv -Path "./userOffices.csv" -NoTypeInformation
