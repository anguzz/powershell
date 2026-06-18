$wildcard = "SG-prefix*"
# for example, app-users-01, app-users-02, app-users-03, etc you would use app-users*

$groups = Get-ADGroup -Filter "Name -like '$wildcard'"

foreach ($group in $groups) {
    $parents = Get-ADPrincipalGroupMembership $group | Where-Object {$_.GroupScope -eq "Global"}

    if ($parents) {
        Write-Host "Group: $($group.Name) already in Global groups:" -ForegroundColor Yellow
        $parents | ForEach-Object { Write-Host "  - $($_.Name)" }
    }
}