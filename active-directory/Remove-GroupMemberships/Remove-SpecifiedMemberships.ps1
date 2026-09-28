[CmdletBinding()]
param(
    [ValidateSet('Test','Remove')]
    [string]$Mode = 'Remove'
)

# Group to remove from all users
$GroupName = 'Target Group here'

$InputPath = Join-Path $PSScriptRoot 'input.csv'

$OutputPath = Join-Path $PSScriptRoot (
    "MembershipRemoval_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss')
)

Import-Module ActiveDirectory -ErrorAction Stop

# Use -Filter on Name instead of -Identity, since -Identity requires
# SamAccountName/DN/GUID/SID, not the display Name.
$Group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction Stop
if (-not $Group) {
    throw "Group '$GroupName' not found. Aborting before touching anything."
}

$Results = foreach ($Row in (Import-Csv $InputPath)) {

    $UPN = $Row.UPN.Trim()

    Write-Host ""
    Write-Host "User : $UPN" -ForegroundColor Cyan

    if ([string]::IsNullOrWhiteSpace($UPN)) {
        Write-Warning "Blank UPN in CSV row, skipping"
        [PSCustomObject]@{
            UPN         = $UPN
            GroupName   = $GroupName
            ActionTaken = 'Blank UPN - skipped'
        }
        continue
    }

    $User = Get-ADUser -Filter "UserPrincipalName -eq '$UPN' -or SamAccountName -eq '$UPN'"

    if (-not $User) {
        Write-Warning "User not found: $UPN"

        [PSCustomObject]@{
            UPN         = $UPN
            GroupName   = $GroupName
            ActionTaken = 'User not found'
        }

        continue
    }

    $IsMember = Get-ADPrincipalGroupMembership $User |
        Where-Object Name -eq $GroupName

    if (-not $IsMember) {

        Write-Host "  Not a member of $GroupName" -ForegroundColor Yellow

        [PSCustomObject]@{
            UPN         = $UPN
            GroupName   = $GroupName
            ActionTaken = 'Not a member'
        }

        continue
    }

    if ($Mode -eq 'Test') {

        Write-Host "  [TEST] Would remove from $GroupName" -ForegroundColor Yellow

        [PSCustomObject]@{
            UPN         = $UPN
            GroupName   = $GroupName
            ActionTaken = 'Would remove'
        }
    }
    else {

        try {
            Remove-ADGroupMember `
                -Identity $Group `
                -Members $User `
                -Confirm:$false `
                -ErrorAction Stop

            Write-Host "  Removed from $GroupName" -ForegroundColor Green

            [PSCustomObject]@{
                UPN         = $UPN
                GroupName   = $GroupName
                ActionTaken = 'Removed'
            }
        }
        catch {
            Write-Warning "  Failed to remove $UPN : $($_.Exception.Message)"

            [PSCustomObject]@{
                UPN         = $UPN
                GroupName   = $GroupName
                ActionTaken = 'Failed'
            }
        }
    }
}

$Results | Export-Csv $OutputPath -NoTypeInformation

Write-Host ""
Write-Host "Results exported to: $OutputPath" -ForegroundColor Green
