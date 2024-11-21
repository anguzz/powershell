$AccountsToKeep = @('Administrator', 'Admin', 'Public', 'Default', 'niagara', 'niagarawater.com\PDQInventory', 'pdqinventory', 'NetworkService', 'LocalService', 'systemprofile')

$UserProfiles = Get-CimInstance -Class Win32_UserProfile | Where-Object {
    $_.LocalPath.Split('\')[-1] -notin $AccountsToKeep
}

foreach ($UserProfile in $UserProfiles) {
    try {
        Remove-CimInstance -InputObject $UserProfile -Confirm:$false
        Write-Host "Removed profile for $($UserProfile.LocalPath.Split('\')[-1])"
    } catch {
        Write-Host "Failed to remove profile for $($UserProfile.LocalPath.Split('\')[-1]): $($_.Exception.Message)"
    }
}
