Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"


$body = @{
    displayName = "Test entra group creation Graph API"
    description = "Example description for new group"
    mailEnabled = $false
    mailNickname = "TestEntraGroup" #fails if following characters in string: @ () \ [] " ; : <> , SPACE
    securityEnabled = $true
} | ConvertTo-Json

$response = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups" -Body $body -ContentType "application/json"

$response.displayName
$response.ID
