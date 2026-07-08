<#
.SYNOPSIS
    Removes and re-adds all direct user members of a cloud security group.

.DESCRIPTION
    Given an Entra ID group object ID, this script exports all direct user members
    to CSV, removes them from the group, waits briefly, and then re-adds them.

    This is intended to create membership change activity that may help trigger
    directory sync or group writeback re-processing.

.NOTES
    - Only direct user members are processed.
    - Nested groups, devices, and service principals are ignored.
    - Dynamic membership groups are blocked.
    - Always exports a CSV backup before changing anything.
    - Supports -WhatIf and per-object confirmations.

.EXAMPLE
    .\Reset-CloudGroupMembers.ps1 -GroupId "00000000-0000-0000-0000-000000000000" -WhatIf

.EXAMPLE
    .\Reset-CloudGroupMembers.ps1 -GroupId "00000000-0000-0000-0000-000000000000"

.EXAMPLE
    .\Reset-CloudGroupMembers.ps1 -GroupId "00000000-0000-0000-0000-000000000000" -ExportOnly

.EXAMPLE
    .\Reset-CloudGroupMembers.ps1 -GroupId "00000000-0000-0000-0000-000000000000" -InputCsv ".\GroupMembers_Backup.csv" -ReAddOnly
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)]
    [string]$GroupId,

    [Parameter(Mandatory = $false)]
    [string]$OutputCsv,

    [Parameter(Mandatory = $false)]
    [string]$InputCsv,

    [Parameter(Mandatory = $false)]
    [switch]$ExportOnly,

    [Parameter(Mandatory = $false)]
    [switch]$ReAddOnly,

    [Parameter(Mandatory = $false)]
    [int]$PauseSecondsBetweenRemoveAndAdd = 30
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Good {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Bad {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Make sure required modules are available
$requiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Groups"
)

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing required module: $module. Install Microsoft Graph PowerShell first."
    }
}

Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Groups


# Connect to Graph using device code authentication

Connect-MgGraph `
    -Scopes Group.ReadWrite.All,Directory.Read.All `
    -UseDeviceCode `

$context = Get-MgContext

Write-Info "Connected as: $($context.Account)"
Write-Info "Tenant ID: $($context.TenantId)"

# Default output CSV name
if (-not $OutputCsv) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputCsv = ".\GroupMembers-$GroupId-$timestamp.csv"
}

# Get group details
Write-Info "Looking up group: $GroupId"

$group = Get-MgGroup -GroupId $GroupId -Property Id,DisplayName,SecurityEnabled,GroupTypes,MembershipRule

if (-not $group) {
    throw "Group not found: $GroupId"
}

Write-Info "Group name: $($group.DisplayName)"
Write-Info "Security enabled: $($group.SecurityEnabled)"
Write-Info "Group types: $($group.GroupTypes -join ', ')"

# Safety checks
if ($group.GroupTypes -contains "DynamicMembership") {
    throw "This appears to be a dynamic membership group. Direct remove/re-add is not supported. Stopping."
}

if ($group.SecurityEnabled -ne $true) {
    Write-Warn "This group is not marked as securityEnabled. Continuing, but verify this is the intended group."
}

$members = @()

if ($InputCsv) {
    Write-Info "Loading members from CSV: $InputCsv"

    if (-not (Test-Path $InputCsv)) {
        throw "Input CSV not found: $InputCsv"
    }

    $members = Import-Csv -Path $InputCsv

    if (-not ($members | Get-Member -Name Id -MemberType NoteProperty)) {
        throw "Input CSV must contain an Id column."
    }
}
else {
    Write-Info "Fetching direct user members from group..."

    # Pull only direct user members.
    # This filters to users only and ignores devices, nested groups, and service principals.
    $uri = "https://graph.microsoft.com/v1.0/groups/$GroupId/members/microsoft.graph.user?`$select=id,displayName,userPrincipalName,mail,accountEnabled"

    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri

        foreach ($user in $response.value) {
            $members += [PSCustomObject]@{
                Id                = $user.id
                DisplayName       = $user.displayName
                UserPrincipalName = $user.userPrincipalName
                Mail              = $user.mail
                AccountEnabled    = $user.accountEnabled
            }
        }

        $uri = $response.'@odata.nextLink'
    }
    while ($uri)

    Write-Info "Found $($members.Count) direct user member(s)."

    # Always export backup before any changes
    $members |
        Sort-Object DisplayName |
        Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

    Write-Good "Exported backup CSV: $OutputCsv"
}

if ($members.Count -eq 0) {
    Write-Warn "No user members found. Nothing to process."
    return
}

if ($ExportOnly) {
    Write-Good "ExportOnly was used. No changes made."
    return
}

if ($ReAddOnly) {
    Write-Warn "ReAddOnly mode enabled. Skipping removals and only adding members from CSV."
}
else {
    Write-Warn "About to remove $($members.Count) user member(s) from group: $($group.DisplayName)"

    foreach ($member in $members) {
        $target = "$($member.DisplayName) <$($member.UserPrincipalName)> [$($member.Id)]"

        try {
            if ($PSCmdlet.ShouldProcess($target, "Remove from group $($group.DisplayName)")) {
                Remove-MgGroupMemberByRef -GroupId $GroupId -DirectoryObjectId $member.Id -ErrorAction Stop
                Write-Good "Removed: $target"
            }
        }
        catch {
            Write-Bad "Failed to remove: $target"
            Write-Bad $_.Exception.Message
        }
    }

    if ($PauseSecondsBetweenRemoveAndAdd -gt 0) {
        Write-Info "Waiting $PauseSecondsBetweenRemoveAndAdd second(s) before re-adding members..."
        Start-Sleep -Seconds $PauseSecondsBetweenRemoveAndAdd
    }
}

Write-Warn "About to re-add $($members.Count) user member(s) to group: $($group.DisplayName)"

foreach ($member in $members) {
    $target = "$($member.DisplayName) <$($member.UserPrincipalName)> [$($member.Id)]"

    try {
        if ($PSCmdlet.ShouldProcess($target, "Add back to group $($group.DisplayName)")) {
            $body = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($member.Id)"
            }

            New-MgGroupMemberByRef -GroupId $GroupId -BodyParameter $body -ErrorAction Stop
            Write-Good "Added: $target"
        }
    }
    catch {
        # If the user is already a member, Graph may return an error.
        # We log it but continue.
        Write-Bad "Failed to add: $target"
        Write-Bad $_.Exception.Message
    }
}

Write-Good "Completed membership reset for group: $($group.DisplayName)"
Write-Good "Backup CSV: $OutputCsv"