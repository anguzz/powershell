#requires -Version 5.1
<#
.SYNOPSIS
    Exports the permissions (allowed resource actions) granted by Entra directory roles.

.DESCRIPTION
    Works with built-in and custom roles. Produces one CSV with a row per role and
    permission, which makes it easy to compare roles side by side or diff a custom
    role against the built-in role it is meant to replace.

.EXAMPLE
    .\05-Export-RolePermissions.ps1 -Roles "Exchange Administrator","Intune Administrator"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Roles,

    [string]$TenantId,

    [string]$ClientId,

    [string]$OutputCsv = ".\RolePermissions.csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$connectParams = @{ Scopes = "RoleManagement.Read.Directory"; NoWelcome = $true }
if ($TenantId) { $connectParams.TenantId = $TenantId }
if ($ClientId) { $connectParams.ClientId = $ClientId }
Connect-MgGraph @connectParams

$rows = foreach ($roleName in $Roles) {
    $role = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$($roleName -replace "'", "''")'"
    if (-not $role) {
        Write-Warning "Role '$roleName' not found."
        continue
    }

    $role.RolePermissions.AllowedResourceActions |
        Sort-Object -Unique |
        ForEach-Object {
            [pscustomobject]@{
                Role       = $role.DisplayName
                RoleType   = if ($role.IsBuiltIn) { "BuiltIn" } else { "Custom" }
                Namespace  = ($_ -split "/")[0]
                Permission = $_
            }
        }
}

$rows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Exported $(@($rows).Count) permissions to $OutputCsv" -ForegroundColor Green
$rows | Group-Object Role | Select-Object Name, Count | Format-Table -AutoSize
