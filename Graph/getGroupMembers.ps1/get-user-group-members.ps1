Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

$groupID = "" #
$apiURL = "https://graph.microsoft.com/v1.0/groups/$groupID/members"

$response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject

$users = $response.value | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.user' }

$selectedProperties = $users | Select-Object @{
    Name='ID';Expression={$_.id}},
    @{Name='DisplayName';Expression={$_.displayName}},
    @{Name='FirstName';Expression={$_.givenName}},
    @{Name='LastName';Expression={$_.surname}},
    @{Name='JobTitle';Expression={$_.jobTitle}},
    @{Name='Email';Expression={$_.mail}},
    @{Name='MobilePhone';Expression={$_.mobilePhone}},
    @{Name='OfficeLocation';Expression={$_.officeLocation}},
    @{Name='UserPrincipalName';Expression={$_.userPrincipalName}}

$selectedProperties | Export-Csv -Path "./GroupMembers.csv" -NoTypeInformation

Write-Host "CSV file created with user details."
