
#will delete users on a device over the network, has a list of accounts to keep


$cred = Get-Credential
$computer = Read-Host "Enter the computer name"
$AccountsToKeep = @('Administrator', 'Admin', 'Public', 'Default', 'niagara', 'niagarawater.com\PDQInventory', 'pdqinventory', 'NetworkService', 'LocalService', 'systemprofile')


Invoke-Command -ComputerName $computer -Credential $cred -ScriptBlock {
    $UserProfiles = Get-CimInstance -Class Win32_UserProfile | Where-Object {
        $_.LocalPath.Split('\')[-1] -notin $using:AccountsToKeep
    }

    foreach ($UserProfile in $UserProfiles) {
        try {
            Remove-CimInstance -InputObject $UserProfile -Confirm:$false
            Write-Host "Removed profile for $($UserProfile.LocalPath.Split('\')[-1])"
        } catch {
            Write-Host "Failed to remove profile for $($UserProfile.LocalPath.Split('\')[-1]): $($_.Exception.Message)"
        }
    }
}
