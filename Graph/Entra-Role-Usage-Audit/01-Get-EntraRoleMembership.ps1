#requires -Version 5.1
<#
.SYNOPSIS
    Exports the members of one or more Microsoft Entra ID directory roles.

.DESCRIPTION
    Resolves active role assignments (and optionally PIM-eligible assignments) for
    any built-in or custom Entra role. Group-based assignments are expanded to their
    user members. Output is a flat CSV with one row per principal, per role, per
    assignment path, enriched with basic identity attributes.

    The script also renders the Defender Advanced Hunting query template
    (02-Get-RoleMemberSignIns.kql) with the discovered user UPNs so it can be pasted
    straight into Advanced Hunting.

.PARAMETER Roles
    Display names of the roles to audit, e.g. "Global Reader","Security Administrator".

.PARAMETER AllRoles
    Audit every role that has at least one assignment.

.PARAMETER IncludeEligible
    Also include PIM-eligible assignments (requires Entra ID P2 and the
    RoleEligibilitySchedule.Read.Directory scope).

.EXAMPLE
    .\01-Get-EntraRoleMembership.ps1 -Roles "Exchange Administrator","Intune Administrator"

.EXAMPLE
    .\01-Get-EntraRoleMembership.ps1 -AllRoles -IncludeEligible -TenantId <tenant-id>
#>
[CmdletBinding(DefaultParameterSetName = "ByName")]
param(
    [Parameter(Mandatory, ParameterSetName = "ByName")]
    [string[]]$Roles,

    [Parameter(Mandatory, ParameterSetName = "All")]
    [switch]$AllRoles,

    [switch]$IncludeEligible,

    [string]$TenantId,

    [string]$ClientId,

    [string]$OutputCsv = ".\RoleMembership.csv",

    [string]$QueryTemplate = (Join-Path $PSScriptRoot "02-Get-RoleMemberSignIns.kql"),

    [string]$QueryOutput = ".\RoleMemberSignIns.rendered.kql"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------
# Connect
# ------------------------------------------------------------

$scopes = @(
    "RoleManagement.Read.Directory",
    "Directory.Read.All",
    "User.Read.All",
    "Group.Read.All"
)
if ($IncludeEligible) { $scopes += "RoleEligibilitySchedule.Read.Directory" }

$connectParams = @{ Scopes = $scopes; NoWelcome = $true }
if ($TenantId) { $connectParams.TenantId = $TenantId }
if ($ClientId) { $connectParams.ClientId = $ClientId }

Connect-MgGraph @connectParams

# ------------------------------------------------------------
# Lookups (cached to avoid repeated Graph calls)
# ------------------------------------------------------------

$userCache = @{}
$objectCache = @{}

function Get-PrincipalType {
    param([string]$PrincipalId)

    if (-not $objectCache.ContainsKey($PrincipalId)) {
        try {
            $obj = Get-MgDirectoryObject -DirectoryObjectId $PrincipalId -ErrorAction Stop
            $objectCache[$PrincipalId] = [pscustomobject]@{
                Type        = ($obj.AdditionalProperties["@odata.type"] -replace "^#microsoft\.graph\.", "")
                DisplayName = $obj.AdditionalProperties["displayName"]
            }
        }
        catch {
            Write-Warning "Unable to resolve principal $PrincipalId. $($_.Exception.Message)"
            $objectCache[$PrincipalId] = $null
        }
    }
    return $objectCache[$PrincipalId]
}

function Get-UserDetail {
    param([string]$UserId)

    if (-not $userCache.ContainsKey($UserId)) {
        try {
            $user = Get-MgUser -UserId $UserId -Property @(
                "Id", "DisplayName", "UserPrincipalName", "Mail", "JobTitle",
                "Department", "AccountEnabled", "UserType"
            ) -ErrorAction Stop

            $managerName = $null
            try {
                $manager = Get-MgUserManager -UserId $UserId -ErrorAction Stop
                $managerName = $manager.AdditionalProperties["displayName"]
            }
            catch { }

            $userCache[$UserId] = [pscustomobject]@{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                Email             = $user.Mail
                JobTitle          = $user.JobTitle
                Department        = $user.Department
                Manager           = $managerName
                UserType          = $user.UserType
                AccountEnabled    = $user.AccountEnabled
            }
        }
        catch {
            Write-Warning "Unable to retrieve user $UserId. $($_.Exception.Message)"
            $userCache[$UserId] = $null
        }
    }
    return $userCache[$UserId]
}

$results = [System.Collections.Generic.List[object]]::new()

function Add-Row {
    param(
        [string]$RoleName,
        [string]$RoleType,
        [string]$AssignmentState,
        [string]$AssignmentType,
        [string]$AssignedGroup,
        [string]$Scope,
        [string]$PrincipalId,
        [string]$PrincipalType,
        [string]$PrincipalName
    )

    $u = if ($PrincipalType -eq "user") { Get-UserDetail $PrincipalId } else { $null }

    $results.Add([pscustomobject]@{
        Role              = $RoleName
        RoleType          = $RoleType
        AssignmentState   = $AssignmentState
        AssignmentType    = $AssignmentType
        AssignedGroup     = $AssignedGroup
        Scope             = $Scope
        PrincipalType     = $PrincipalType
        DisplayName       = if ($u) { $u.DisplayName } else { $PrincipalName }
        UserPrincipalName = if ($u) { $u.UserPrincipalName } else { $null }
        Email             = if ($u) { $u.Email } else { $null }
        JobTitle          = if ($u) { $u.JobTitle } else { $null }
        Department        = if ($u) { $u.Department } else { $null }
        Manager           = if ($u) { $u.Manager } else { $null }
        UserType          = if ($u) { $u.UserType } else { $null }
        AccountEnabled    = if ($u) { $u.AccountEnabled } else { $null }
        PrincipalId       = $PrincipalId
    })
}

function Resolve-Assignment {
    param(
        [object]$RoleDefinition,
        [string]$PrincipalId,
        [string]$Scope,
        [string]$State
    )

    $principal = Get-PrincipalType $PrincipalId
    if (-not $principal) { return }

    $roleType = if ($RoleDefinition.IsBuiltIn) { "BuiltIn" } else { "Custom" }

    if ($principal.Type -eq "group") {
        Write-Host "  Expanding group: $($principal.DisplayName)" -ForegroundColor Yellow
        $members = Get-MgGroupTransitiveMember -GroupId $PrincipalId -All
        foreach ($m in $members) {
            $mType = $m.AdditionalProperties["@odata.type"] -replace "^#microsoft\.graph\.", ""
            if ($mType -in @("group")) { continue }
            Add-Row -RoleName $RoleDefinition.DisplayName -RoleType $roleType `
                -AssignmentState $State -AssignmentType "Group" `
                -AssignedGroup $principal.DisplayName -Scope $Scope `
                -PrincipalId $m.Id -PrincipalType $mType `
                -PrincipalName $m.AdditionalProperties["displayName"]
        }
    }
    else {
        Add-Row -RoleName $RoleDefinition.DisplayName -RoleType $roleType `
            -AssignmentState $State -AssignmentType "Direct" `
            -AssignedGroup $null -Scope $Scope `
            -PrincipalId $PrincipalId -PrincipalType $principal.Type `
            -PrincipalName $principal.DisplayName
    }
}

# ------------------------------------------------------------
# Resolve role definitions
# ------------------------------------------------------------

$allDefinitions = @(Get-MgRoleManagementDirectoryRoleDefinition -All)

if ($AllRoles) {
    $targetDefinitions = $allDefinitions
}
else {
    $targetDefinitions = foreach ($name in $Roles) {
        $def = $allDefinitions | Where-Object DisplayName -eq $name | Select-Object -First 1
        if ($def) { $def } else { Write-Warning "Role '$name' was not found." }
    }
}

# ------------------------------------------------------------
# Collect assignments
# ------------------------------------------------------------

foreach ($def in $targetDefinitions) {

    $active = @(Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$($def.Id)'" -All)

    $eligible = @()
    if ($IncludeEligible) {
        try {
            $eligible = @(Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "roleDefinitionId eq '$($def.Id)'" -All)
        }
        catch {
            Write-Warning "Unable to read eligible assignments for '$($def.DisplayName)'. $($_.Exception.Message)"
        }
    }

    if ($active.Count -eq 0 -and $eligible.Count -eq 0) { continue }

    Write-Host "Processing role: $($def.DisplayName) ($($active.Count) active, $($eligible.Count) eligible)" -ForegroundColor Cyan

    foreach ($a in $active) {
        Resolve-Assignment -RoleDefinition $def -PrincipalId $a.PrincipalId -Scope $a.DirectoryScopeId -State "Active"
    }
    foreach ($e in $eligible) {
        Resolve-Assignment -RoleDefinition $def -PrincipalId $e.PrincipalId -Scope $e.DirectoryScopeId -State "Eligible"
    }
}

if ($results.Count -eq 0) {
    Write-Warning "No role assignments found for the selected roles."
    return
}

# ------------------------------------------------------------
# Export membership
# ------------------------------------------------------------

$finalResults = $results |
    Sort-Object Role, PrincipalId, AssignmentState, AssignmentType, AssignedGroup, Scope -Unique |
    Sort-Object Role, Department, DisplayName

$finalResults | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "Membership export: $OutputCsv" -ForegroundColor Green
$finalResults | Group-Object Role | Select-Object Name, Count | Sort-Object Count -Descending | Format-Table -AutoSize

# ------------------------------------------------------------
# Render the hunting query with the discovered UPNs
# ------------------------------------------------------------

$upns = @(
    $finalResults |
    Where-Object { $_.UserPrincipalName } |
    ForEach-Object { $_.UserPrincipalName.ToLowerInvariant() } |
    Sort-Object -Unique
)

if ((Test-Path -LiteralPath $QueryTemplate) -and $upns.Count -gt 0) {
    $upnList = ($upns | ForEach-Object { "    `"$_`"" }) -join ",`n"
    $template = Get-Content -LiteralPath $QueryTemplate -Raw
    $pattern = '(?s)(let RoleMembers = dynamic\(\[).*?(\]\);)'
    [regex]::Replace($template, $pattern, { param($m) "$($m.Groups[1].Value)`n$upnList`n$($m.Groups[2].Value)" }) |
        Set-Content -LiteralPath $QueryOutput -Encoding UTF8
    Write-Host "Hunting query rendered with $($upns.Count) users: $QueryOutput" -ForegroundColor Green
}
