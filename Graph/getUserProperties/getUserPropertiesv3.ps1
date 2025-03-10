Connect-MgGraph -Scopes "User.Read.All"

$users = Import-Csv -Path "./userEmails.csv"

$results = @()

foreach ($user in $users) {
    $userEmail = $user.emailAddress
    Write-Host "Processing: $userEmail"  # Added for visibility

    $selectProperties = "mail,officeLocation,onPremisesDistinguishedName" #select string for  properties
    $apiURL = "https://graph.microsoft.com/v1.0/users/$userEmail`?`$select=$selectProperties"

    try {
        $response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject
        if ($response) {
            $email = $response.mail
            $officeLocation = $response.officeLocation
            $onPremisesDN =$response.onPremisesDistinguishedName


            $results += [PSCustomObject]@{
                Email = $email
                OfficeLocation = $officeLocation
                OnPremisesDistinguishedName = $onPremisesDN
            }
        } else {
            Write-Host "No data returned for: $userEmail"
        }
    } catch {
        Write-Error "Failed to fetch data for $userEmail"
    }
}

$results | Export-Csv -Path "./userOffices.csv" -NoTypeInformation
