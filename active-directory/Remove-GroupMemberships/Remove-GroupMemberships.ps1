<#
.SYNOPSIS
Removes direct Active Directory group memberships for users listed by UPN.

.INPUT CSV
UPN
user1@contoso.com
user2@contoso.com

.NOTES
- Test mode is the default.
- Only direct group memberships are processed.
- The user's primary group, usually Domain Users, is not removed.
#>

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Remove')]
    [string]$Mode = 'Test'
)

$InputPath = Join-Path $PSScriptRoot 'input.csv'

$OutputPath = Join-Path $PSScriptRoot (
    "GroupMembershipRemoval_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss')
)


Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}

$InputUsers = Import-Csv -LiteralPath $InputPath

if (-not $InputUsers) {
    throw "The input CSV is empty."
}

if ('UPN' -notin $InputUsers[0].PSObject.Properties.Name) {
    throw "The input CSV must contain a single column named 'UPN'."
}

$ADParameters = @{}

if ($Server) {
    $ADParameters.Server = $Server
}

$Results = foreach ($Entry in $InputUsers) {
    $UPN = $Entry.UPN.Trim()

    if (:IsNullOrWhiteSpace($UPN)) {
        continue
    }

    Write-Host ""
    Write-Host "User: $UPN" -ForegroundColor Cyan

    try {
        $User = Get-ADUser `
            -Filter { UserPrincipalName -eq $UPN } `
            -Properties MemberOf `
            @ADParameters `
            -ErrorAction Stop

        if (-not $User) {
            Write-Warning "User not found: $UPN"

            [PSCustomObject]@{
                UPN                = $UPN
                MembershipsRemoved = 'ERROR: User not found'
            }

            continue
        }

        $Groups = foreach ($GroupDN in $User.MemberOf) {
            try {
                Get-ADGroup `
                    -Identity $GroupDN `
                    @ADParameters `
                    -ErrorAction Stop
            }
            catch {
                Write-Warning "Unable to resolve group: $GroupDN"
            }
        }

        $Groups = @($Groups | Sort-Object Name)

        if ($Groups.Count -eq 0) {
            Write-Host "  No direct group memberships found." -ForegroundColor DarkGray

            [PSCustomObject]@{
                UPN                = $UPN
                MembershipsRemoved = ''
            }

            continue
        }

        $ProcessedGroups = [System.Collections.Generic.List[string]]::new()

        foreach ($Group in $Groups) {
            if ($Mode -eq 'Test') {
                Write-Host "  [TEST] Would remove: $($Group.Name)" -ForegroundColor Yellow
                $ProcessedGroups.Add($Group.Name)
            }
            else {
                Write-Host "  [REMOVE] Removing: $($Group.Name)" -ForegroundColor Red

                try {
                    Remove-ADGroupMember `
                        -Identity $Group `
                        -Members $User `
                        -Confirm:$false `
                        @ADParameters `
                        -ErrorAction Stop

                    $ProcessedGroups.Add($Group.Name)
                }
                catch {
                    Write-Warning "Failed to remove $UPN from $($Group.Name): $($_.Exception.Message)"
                }
            }
        }

        [PSCustomObject]@{
            UPN                = $UPN
            MembershipsRemoved = $ProcessedGroups -join '; '
        }
    }
    catch {
        Write-Warning "Failed to process $UPN`: $($_.Exception.Message)"

        [PSCustomObject]@{
            UPN                = $UPN
            MembershipsRemoved = "ERROR: $($_.Exception.Message)"
        }
    }
}

$Results | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Mode: $Mode" -ForegroundColor Cyan
Write-Host "Results exported to: $OutputPath" -ForegroundColor Green

if ($Mode -eq 'Test') {
    Write-Host "No memberships were removed. Run with -Mode Remove to apply the changes." -ForegroundColor Yellow
}