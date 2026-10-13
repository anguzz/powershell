# Azure RBAC Role Permission Review with PowerShell

## Overview

Azure role names and portal descriptions do not always show the full permission scope. Before adding a new role assignment, review the underlying RBAC actions to determine whether an existing role already provides the requested access.

The `Get-AzRoleDefinition` cmdlet provides a direct way to inspect role permissions through PowerShell instead of relying only on the Azure portal GUI.

## Prerequisites

Install or import the official Microsoft `Az.Resources` module, then connect to Azure:

```powershell
Install-Module -Name Az.Resources -Scope CurrentUser
Import-Module Az.Resources
Connect-AzAccount
```

Select any appropriate subscription in the target Microsoft Entra tenant. Built-in role definitions can then be reviewed from the connected Azure context.

## Review a role definition

```powershell
Get-AzRoleDefinition -Name "Role Name" |
    Select-Object -ExpandProperty Permissions
```

The output shows the role's underlying permission fields:

- `Actions`
- `NotActions`
- `DataActions`
- `NotDataActions`

For a cleaner list of management-plane actions:

```powershell
(Get-AzRoleDefinition -Name "Role Name").Permissions.Actions
```

## Compare two roles

```powershell
$roleA = (Get-AzRoleDefinition -Name "First Role").Permissions.Actions
$roleB = (Get-AzRoleDefinition -Name "Second Role").Permissions.Actions

Compare-Object -ReferenceObject $roleA -DifferenceObject $roleB
```

This helps identify permissions explicitly listed in one role but not the other.

## Important wildcard consideration

A permission such as:

```text
Microsoft.Compute/galleries/*
```

covers operations beneath that resource path unless a relevant operation is excluded by `NotActions`. A basic `Compare-Object` command compares strings and does not expand wildcard permissions into every covered action.

When one role contains a wildcard, compare the requested operation against that wildcard manually and review `NotActions` before concluding that access is missing.

## Suggested review process

1. Confirm the requester receives the existing role assignment through the expected user, group, or managed identity.
2. Check the assignment scope and whether access is active, eligible, direct, or inherited.
3. Use `Get-AzRoleDefinition` to inspect the current and requested roles.
4. Compare `Actions`, `NotActions`, `DataActions`, and `NotDataActions`.
5. Account for wildcard permissions and exclusions.
6. Add another role only when the existing assignment does not already provide the required operation.
7. If access should already exist, request the exact authorization error and review Azure Activity Log details.

## Key takeaway

`Get-AzRoleDefinition` provides another reliable method for reviewing Azure RBAC permissions beyond the portal GUI. It is useful for validating access requests, comparing built-in or custom roles, identifying overlapping permissions, and avoiding redundant role assignments.
