
# Add-ServicePrincipalOwnerToGroups

PowerShell script that bulk-adds a **service principal** as an **Owner** on Entra ID (Azure AD) groups from a CSV list.

Useful for scenarios where an automation identity (managed identity, app registration, or workload SP) needs owner rights on a set of groups. 

## Requirements

### PIM Roles

- **Privileged Role Administrator** – required for role-assignable (privileged) groups
- **Groups Administrator** – sufficient for most non-privileged groups

Activate the appropriate role in PIM before running.

### Graph Module

Install the Microsoft Graph PowerShell SDK if not already present:

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
````

Only these submodules are strictly required by the script:

* Microsoft.Graph.Authentication
* Microsoft.Graph.Applications
* Microsoft.Graph.Groups

All installed Graph modules should be on the **same version**. Mixed versions cause `AggregateException` errors on cmdlet load.

### Graph Permissions

The script requests the following delegated scopes:

* `Group.ReadWrite.All`
* `Application.Read.All`
* `RoleManagement.ReadWrite.Directory` *(required for role-assignable groups)*


## Files

* `Add-ServicePrincipalOwnerToGroups.ps1` – main script
* `Groups.csv` – input file with a single column `GroupName`
* `OwnerUpdate_<timestamp>.csv` – auto-generated run log

### CSV Format

```csv
GroupName
Group1
Group2
Group3
Group4
```

## Usage

### Dry Run (recommended first)

```powershell
.\Add-ServicePrincipalOwnerToGroups.ps1 -WhatIf
```

Confirms every group is found in the directory and shows which ones would be updated. No changes are made.

### Actual Run

```powershell
.\Add-ServicePrincipalOwnerToGroups.ps1
```

### Expected Output

```
Processing: Group1
Owner added successfully.

Processing: Group2
Owner added successfully.

Processing: Group3
Owner added successfully.

Processing: Group4
Owner added successfully.

...

Results exported to: .\OwnerUpdate_timestamp.csv
```

## Parameters

| Parameter               | Default                         | Description                                      |
| ----------------------- | ------------------------------- | ------------------------------------------------ |
| `-CsvPath`              | `.\Groups.csv`                  | Path to the input CSV                            |
| `-ServicePrincipalName` | `(required)`                | Display name of the SP to add as owner           |
| `-LogPath`              | `.\OwnerUpdate_<timestamp>.csv` | Path for the run results log                     |
| `-WhatIf`               | *(off)*                         | Dry run – reports actions without making changes |

## Output Log

Each run generates a CSV log with the status of every processed group:

| Status            | Meaning                                        |
| ----------------- | ---------------------------------------------- |
| `Added`           | Owner successfully assigned                    |
| `AlreadyAssigned` | SP was already an owner                        |
| `NotFound`        | Group name did not exist in the directory      |
| `Failed`          | Graph returned an error (see `Message` column) |
| `WhatIf`          | Would have added the owner (dry run)           |


