# Reset-CloudGroupMembers.ps1

PowerShell utility for resetting the membership of an Entra ID cloud security group by exporting the current members to CSV, removing them, waiting briefly, then re-adding them.

Useful when you need to force/re-sync membership change activity on a group.

***

## What the script does

1. Connects to Microsoft Graph using device code authentication.
2. Fetches all **direct user members** of the specified group.
3. Exports a CSV backup of the current membership.
4. Removes all direct user members from the group.
5. Waits a configurable number of seconds.
6. Re-adds the same users back to the group.

Nested groups, devices, and service principals are ignored. Only direct user members are affected.

***

## When you might use this

* A cloud security group is not syncing membership as expected.
* You want to force a re-provision by generating membership change events.
* You need a repeatable, auditable way to bulk remove/re-add members with a CSV backup.
* You want a fallback CSV so recovery is possible if the process fails partway.

This script does not repair underlying sync configuration or attribute issues. It only manipulates group membership.

***

## Prerequisites

**PowerShell modules**

* `Microsoft.Graph.Authentication`
* `Microsoft.Graph.Groups`

Install if missing:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

**Entra roles**

Assign roles based on what the script will do in your tenant. Typical requirements:

* **Groups Administrator** (or equivalent) — required to modify group membership through Graph.
* **Hybrid Identity Administrator** — required if you also plan to interact with Cloud Sync operations.

Role requirements may differ if the target group is role-assignable, dynamic, or governed by additional policies.

**Graph scopes**

* `Group.ReadWrite.All`
* `Directory.Read.All`

***

## Usage

**Dry run (recommended first)**

```powershell
.\Reset-CloudGroupMembers.ps1 -GroupId "GROUP-OBJECT-ID-HERE" -WhatIf
```

Shows what would happen without making changes.

**Export current members only**

```powershell
.\Reset-CloudGroupMembers.ps1 -GroupId "GROUP-OBJECT-ID-HERE" -ExportOnly
```

Creates a CSV backup and exits. No removals or adds.

**Export + WhatIf**

```powershell
.\Reset-CloudGroupMembers.ps1 -GroupId "GROUP-OBJECT-ID-HERE" -ExportOnly -WhatIf
```

Shows what the export would do without writing a file.

**Full reset (real changes)**

```powershell
.\Reset-CloudGroupMembers.ps1 -GroupId "GROUP-OBJECT-ID-HERE"
```

Exports CSV backup, removes all members, waits, and re-adds all members.

**Re-add members from an existing CSV**

```powershell
.\Reset-CloudGroupMembers.ps1 `
  -GroupId "GROUP-OBJECT-ID-HERE" `
  -InputCsv ".\GroupMembers-GROUPID-TIMESTAMP.csv" `
  -ReAddOnly
```

Used to recover if the re-add phase failed on a previous run.

***

## Parameters

| Parameter                          | Type   | Required | Description                                                                             |
| ---------------------------------- | ------ | -------- | --------------------------------------------------------------------------------------- |
| `-GroupId`                         | string | Yes      | Object ID of the Entra security group.                                                  |
| `-OutputCsv`                       | string | No       | Custom path for the backup CSV. Defaults to `.\GroupMembers-<GroupId>-<timestamp>.csv`. |
| `-InputCsv`                        | string | No       | Path to an existing CSV used with `-ReAddOnly`.                                         |
| `-ExportOnly`                      | switch | No       | Export the member list, then exit.                                                      |
| `-ReAddOnly`                       | switch | No       | Skip the removal phase and only re-add from `-InputCsv`.                                |
| `-PauseSecondsBetweenRemoveAndAdd` | int    | No       | Delay between remove and add phases. Default 30.                                        |
| `-WhatIf`                          | switch | No       | Preview mode. No changes made.                                                          |

***

## Recommended workflow

1. Ensure you have the required roles 

2. Backup first:

   ```powershell
   .\Reset-CloudGroupMembers.ps1 -GroupId "GROUP-OBJECT-ID-HERE" -ExportOnly
   ```

3. Preview the operation:

   ```powershell
   .\Reset-CloudGroupMembers.ps1 -GroupId "GROUP-OBJECT-ID-HERE" -WhatIf
   ```

4. Run for real:

   ```powershell
   .\Reset-CloudGroupMembers.ps1 -GroupId "GROUP-OBJECT-ID-HERE"
   ```

5. Verify the outcome in your sync or provisioning logs and, if applicable, on the downstream target.

***

## Safety notes

* Only direct user members are affected. Nested groups, devices, and service principals are skipped.
* Dynamic membership groups are blocked automatically.
* The CSV backup is written **before** any removals occur.
* The script supports `-WhatIf` and per-object confirmations.
* If a removal fails partway through, the CSV backup can be used with `-ReAddOnly` to recover.
* Membership changes will generate audit log entries. Expect visible activity in your directory audit logs and any connected SIEM.

***

## Known limitations

* Does not resolve underlying directory sync or source-of-authority issues. It only forces membership change activity.
* Does not modify group attributes. If sync errors are caused by attribute state on the group, this script will not repair them.
* Does not call Cloud Sync `provisionOnDemand` APIs. Membership churn is the mechanism used to encourage re-sync.
* Not intended for role-assignable groups without additional privilege. Confirm role requirements before running against sensitive groups.

***

## Disclaimer

Use at your own risk. Always run with `-WhatIf` and `-ExportOnly` first, review the CSV backup, and validate in a non-production environment where possible before running against production groups.
