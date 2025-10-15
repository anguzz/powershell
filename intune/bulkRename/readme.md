# bulk-rename.ps1

## Overview

This PowerShell script automatically standardizes all Intune-managed Windows device names to the format **OrgName-{serialnumber}** using the **Microsoft Graph API** in your tenant.
It ensures consistent endpoint naming across **Intune**.

The script supports exclusions, generates a detailed CSV action report, and can run in **WhatIf** mode to preview changes without applying them.

---

## Features

* Bulk rename all physical Windows devices in Intune
* Exclusion list to skip specific devices
* CSV report generation for all rename actions
* Summary of results and errors
* `-WhatIf` parameter for simulation
* Clean Graph connection handling

---

## Usage

### Run Normally

```powershell
.\bulk-rename.ps1
```

Connects to Microsoft Graph, renames noncompliant devices, and generates a CSV report.

### Simulate Changes

```powershell
.\bulk-rename.ps1 -WhatIf
```

Shows which devices would be renamed without making any changes.

---

## Example Output

```bash
Action report saved to: C:\Users\anguzz\Documents\IntuneDeviceRename_Report_20251015_155130.csv

Operation Summary:
---------------------
Total devices evaluated: 8803
Rename actions queued: 8146
Devices already compliant: 644
Devices skipped (in exclusion list): 3
Devices skipped (no serial): 0
Errors encountered: 10

All rename requests submitted. Devices will update their names after their next Intune check-in.
```

