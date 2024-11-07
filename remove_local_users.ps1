
#will delete users on a device over the network, has a list of accounts to keep



$cred = Get-Credential
$computer = Read-Host "Enter the computer name"
$AccountsToKeep = @('Administrator', 'Admin', 'Public', 'Default', 'niagara', 'niagarawater.com\PDQInventory', 'pdqinventory', 'NetworkService', 'LocalService', 'systemprofile')

Invoke-Command -ComputerName $computer -Credential $cred -ScriptBlock {
    $UserProfiles = Get-CimInstance -Class Win32_UserProfile | Where-Object {
        $_.LocalPath.Split('\')[-1] -notin $using:AccountsToKeep
    }
    $TotalProfiles = $UserProfiles.Count
    $ProgressCount = 0

    foreach ($UserProfile in $UserProfiles) {
        $ProfileName = $UserProfile.LocalPath.Split('\')[-1]
        Write-Host "Attempting to remove profile for $ProfileName..."

        try {
            Remove-CimInstance -InputObject $UserProfile -Confirm:$false
            Write-Host "Removed profile for $ProfileName"
        } catch {
            Write-Host "Failed to remove profile for $ProfileName $($_.Exception.Message)"
        }

        $ProgressCount++
        $ProgressPercent = ($ProgressCount / $TotalProfiles) * 100
        Write-Progress -Activity "Removing User Profiles" -Status "Progress: $ProgressCount of $TotalProfiles" -PercentComplete $ProgressPercent
    }

    Write-Progress -Activity "Removing User Profiles" -Status "Complete" -Completed
}

