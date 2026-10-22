#requires -Version 5.1
<#
.SYNOPSIS
    Joins role membership with observed sign-in activity.

.DESCRIPTION
    Takes the membership CSV from 01-Get-EntraRoleMembership.ps1 and the sign-in
    CSV exported from 02-Get-RoleMemberSignIns.kql, aggregates sign-in activity per
    user, and appends it to every membership row. The result is a single CSV that
    the dashboard (04-RoleUsageDashboard.py) can slice by role, department, job
    title, resource, and application.

.EXAMPLE
    .\03-Merge-RoleUsage.ps1 -RoleMembershipCsv .\RoleMembership.csv `
        -SignInCsv .\RoleMemberSignIns.csv -OutputCsv .\RoleUsageAnalysis.csv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$RoleMembershipCsv,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$SignInCsv,

    [string]$OutputCsv = ".\RoleUsageAnalysis.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

function Find-Column {
    param([object]$Row, [string[]]$Candidates, [switch]$Required)

    $names = @($Row.PSObject.Properties.Name)
    foreach ($candidate in $Candidates) {
        $found = $names | Where-Object { $_ -ieq $candidate } | Select-Object -First 1
        if ($found) { return [string]$found }
    }
    if ($Required) {
        throw "Missing required column. Expected one of: $($Candidates -join ', '). Found: $($names -join ', ')"
    }
    return $null
}

function Get-Value {
    param([object]$Row, [string]$Column)
    if (-not $Column) { return $null }
    $value = $Row.$Column
    if ($null -eq $value) { return $null }
    return ([string]$value).Trim()
}

function ConvertTo-Long {
    param([object]$Value)
    $number = 0L
    if ($null -ne $Value) { [void][long]::TryParse(([string]$Value).Trim(), [ref]$number) }
    return $number
}

function ConvertTo-Date {
    param([object]$Value)
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $date = [datetime]::MinValue
    if ([datetime]::TryParse([string]$Value, [ref]$date)) { return $date }
    return $null
}

# ------------------------------------------------------------
# Import
# ------------------------------------------------------------

$members = @(Import-Csv -LiteralPath $RoleMembershipCsv)
$signIns = @(Import-Csv -LiteralPath $SignInCsv)

if ($members.Count -eq 0) { throw "Role membership CSV is empty." }
if ($signIns.Count -eq 0) { Write-Warning "Sign-in CSV is empty. All rows will show no observed activity." }

$mUpn = Find-Column $members[0] @("UserPrincipalName", "UPN", "AccountUpn") -Required

if ($signIns.Count -gt 0) {
    $s = $signIns[0]
    $sUpn        = Find-Column $s @("AccountUpn", "UserPrincipalName", "UPN") -Required
    $sApp        = Find-Column $s @("Application", "AppDisplayName") -Required
    $sResource   = Find-Column $s @("ResourceDisplayName", "Resource") -Required
    $sCount      = Find-Column $s @("SignIns", "Count") -Required
    $sActiveDays = Find-Column $s @("ActiveDays", "DistinctDays")
    $sFirst      = Find-Column $s @("FirstSeen", "FirstSignIn")
    $sLast       = Find-Column $s @("LastSeen", "LastSignIn")
}

# ------------------------------------------------------------
# Aggregate sign-in activity per user
# ------------------------------------------------------------

$usageByUpn = @{}

foreach ($group in ($signIns | Group-Object { ([string](Get-Value $_ $sUpn)).ToLowerInvariant() })) {

    if (-not $group.Name) { continue }
    $rows = @($group.Group)

    $resourceTotals = [ordered]@{}
    $apps = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $total = 0L
    $activeDays = 0L
    $first = $null
    $last = $null

    foreach ($r in $rows) {
        $count = ConvertTo-Long (Get-Value $r $sCount)
        $total += $count

        $resource = Get-Value $r $sResource
        if ($resource) {
            if (-not $resourceTotals.Contains($resource)) { $resourceTotals[$resource] = 0L }
            $resourceTotals[$resource] += $count
        }

        $app = Get-Value $r $sApp
        if ($app) { [void]$apps.Add($app) }

        $activeDays = [math]::Max($activeDays, (ConvertTo-Long (Get-Value $r $sActiveDays)))

        $f = ConvertTo-Date (Get-Value $r $sFirst)
        if ($f -and (-not $first -or $f -lt $first)) { $first = $f }

        $l = ConvertTo-Date (Get-Value $r $sLast)
        if ($l -and (-not $last -or $l -gt $last)) { $last = $l }
    }

    $resourceNames = @($resourceTotals.Keys | Sort-Object)

    $usageByUpn[$group.Name] = [pscustomobject]@{
        ResourceCount    = $resourceNames.Count
        Resources        = $resourceNames -join "; "
        ResourceUsage    = ($resourceNames | ForEach-Object { "$_ ($($resourceTotals[$_]))" }) -join "; "
        ApplicationCount = $apps.Count
        Applications     = @($apps) -join "; "
        TotalSignIns     = $total
        ActiveDays       = $activeDays
        FirstSeen        = $first
        LastSeen         = $last
    }
}

# ------------------------------------------------------------
# Merge
# ------------------------------------------------------------

$now = Get-Date

$output = foreach ($row in $members) {

    $upn = Get-Value $row $mUpn
    $key = if ($upn) { $upn.ToLowerInvariant() } else { $null }
    $usage = if ($key -and $usageByUpn.ContainsKey($key)) { $usageByUpn[$key] } else { $null }

    $merged = [ordered]@{}
    foreach ($p in $row.PSObject.Properties) { $merged[$p.Name] = $p.Value }

    $merged["HasObservedActivity"] = [bool]$usage
    $merged["TotalSignIns"]        = if ($usage) { $usage.TotalSignIns } else { 0 }
    $merged["ActiveDays"]          = if ($usage) { $usage.ActiveDays } else { 0 }
    $merged["ResourceCount"]       = if ($usage) { $usage.ResourceCount } else { 0 }
    $merged["Resources"]           = if ($usage) { $usage.Resources } else { $null }
    $merged["ResourceUsage"]       = if ($usage) { $usage.ResourceUsage } else { $null }
    $merged["ApplicationCount"]    = if ($usage) { $usage.ApplicationCount } else { 0 }
    $merged["Applications"]        = if ($usage) { $usage.Applications } else { $null }
    $merged["FirstSeen"]           = if ($usage -and $usage.FirstSeen) { $usage.FirstSeen.ToString("s") } else { $null }
    $merged["LastSeen"]            = if ($usage -and $usage.LastSeen) { $usage.LastSeen.ToString("s") } else { $null }
    $merged["DaysSinceLastSeen"]   = if ($usage -and $usage.LastSeen) { [int]($now - $usage.LastSeen).TotalDays } else { $null }

    [pscustomobject]$merged
}

$output | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

$matched = @($output | Where-Object HasObservedActivity).Count

Write-Host ""
Write-Host "Output:                         $OutputCsv" -ForegroundColor Green
Write-Host "Membership rows:                $($members.Count)"
Write-Host "Rows with observed activity:    $matched"
Write-Host "Rows without observed activity: $($members.Count - $matched)"
