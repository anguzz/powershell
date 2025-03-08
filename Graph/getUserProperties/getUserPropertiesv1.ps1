Connect-MgGraph -Scopes "User.Read.All" 

$userEmail="test@email.com"
$apiURL = "https://graph.microsoft.com/v1.0/users/$userEmail"

$response = Invoke-MgGraphRequest -Method GET -Uri $apiURL -OutputType PSObject

$response.mail
$response.officeLocation
