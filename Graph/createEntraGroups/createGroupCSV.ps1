Connect-MgGraph -Scopes "User.Read", "Group.ReadWrite.All", "Directory.ReadWrite.All"

$groupNames = Import-Csv -Path "./groups.csv"

$outputData = @()

foreach ($groupName in $groupNames) {
    $body = @{
        displayName = $groupName.GroupName  
        description = "Windows 11 region update group"
        mailEnabled = $false
        mailNickname = "Windows11UpdateGroup" #fails if  @ () \ [] " ; : <> , SPACE characters present, currently using default name since mail is disabled to avoid writing santize function
        securityEnabled = $true
    } | ConvertTo-Json

    $response = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups" -Body $body -ContentType "application/json"

    $outputData += [PSCustomObject]@{
        GroupName = $response.displayName
        GroupID = $response.id
    }
}

$outputData | Export-Csv -Path "./createdGroups.csv" -NoTypeInformation
