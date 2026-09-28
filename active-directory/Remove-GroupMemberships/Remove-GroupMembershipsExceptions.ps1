<#
.SYNOPSIS
Removes direct Active Directory group memberships for users listed by UPN,
skipping any groups listed in an exception list.

.INPUT CSV
UPN
user1@contoso.com
user2@contoso.com

.EXCEPTIONS
Groups you never want touched, even if the user is a member. Provide either:
  - The -ExceptionGroups parameter (array of group names), and/or
  - An exceptions.txt file in the script folder, one group name per line.
Both sources are combined. Matching is case-insensitive and exact on Name.

.NOTES
- Test mode is the default.
- Only direct group memberships are processed.
#>

[CmdletBinding()]
param(
    [ValidateSet('Test', 'Remove')]
    [string]$Mode = 'Test',

    [string]$Server,

    # Group names that must NEVER be removed, even if the user is a member.
    [string[]]$ExceptionGroups = @("Group Example Here")
)

$InputPath = Join-Path $PSScriptRoot 'input.csv'
$ExceptionsFilePath = Join-Path $PSScriptRoot 'exceptions.txt'

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

# Build the combined exception list: parameter input + optional exceptions.txt
$ExceptionSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($Name in $ExceptionGroups) {
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        [void]$ExceptionSet.Add($Name.Trim())
    }
}

if (Test-Path -LiteralPath $ExceptionsFilePath) {
    foreach ($Line in (Get-Content -LiteralPath $ExceptionsFilePath)) {
        if (-not [string]::IsNullOrWhiteSpace($Line)) {
            [void]$ExceptionSet.Add($Line.Trim())
        }
    }
}

if ($ExceptionSet.Count -gt 0) {
    Write-Host "Exception list loaded ($($ExceptionSet.Count) group(s)):" -ForegroundColor Cyan
    $ExceptionSet | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
    Write-Host ""
}

$ADParameters = @{}

if ($Server) {
    $ADParameters.Server = $Server
}

$Results = foreach ($Entry in $InputUsers) {
    $UPN = $Entry.UPN.Trim()

    if ([string]::IsNullOrWhiteSpace($UPN)) {
        continue
    }

    Write-Host ""
    Write-Host "User: $UPN" -ForegroundColor Cyan

    try {
        $User = Get-ADUser `
        -Filter { UserPrincipalName -eq $UPN -or SamAccountName -eq $UPN } `
        -Properties MemberOf `
        @ADParameters `
        -ErrorAction Stop
        
        if (-not $User) {
            Write-Warning "User not found: $UPN"

            [PSCustomObject]@{
                UPN                 = $UPN
                MembershipsRemoved  = 'ERROR: User not found'
                MembershipsSkipped  = ''
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
                UPN                 = $UPN
                MembershipsRemoved  = ''
                MembershipsSkipped  = ''
            }

            continue
        }

        $ProcessedGroups = [System.Collections.Generic.List[string]]::new()
        $SkippedGroups    = [System.Collections.Generic.List[string]]::new()

        foreach ($Group in $Groups) {

            if ($ExceptionSet.Contains($Group.Name)) {
                Write-Host "  [SKIP - EXCEPTION] $($Group.Name)" -ForegroundColor DarkYellow
                $SkippedGroups.Add($Group.Name)
                continue
            }

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
            UPN                 = $UPN
            MembershipsRemoved  = $ProcessedGroups -join '; '
            MembershipsSkipped  = $SkippedGroups -join '; '
        }
    }
    catch {
        Write-Warning "Failed to process $UPN`: $($_.Exception.Message)"

        [PSCustomObject]@{
            UPN                 = $UPN
            MembershipsRemoved  = "ERROR: $($_.Exception.Message)"
            MembershipsSkipped  = ''
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
