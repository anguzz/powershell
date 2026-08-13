# Cost Centerer Group builder

## Overview

This folder contains two PowerShell scripts that take a single source AD group and split
its members into multiple attribute-based groups.

The typical case is a shared group that needs to be broken out by cost center. You export
the members once, then create one group per cost center and place each user into the group
that matches their attribute value. Once the groups exist, they can be used with any
application that assigns access by cost center.

Both scripts are configured by editing variables at the top. No parameters are passed at
runtime. All input and output files live in this folder.

## Files

### Get-ADGroupMemberAttributes.ps1

Exports all user members of the source group, along with selected attributes including the
grouping attribute. Also writes a list of the unique attribute values found.

### Add-ADUsersToAttributeGroups.ps1

Reads the export, builds a group name per attribute value, creates missing groups, and adds
each user to the matching group. Supports a dry run.

### Generated files

- `GroupMembers.csv` - the exported members.
- `UniqueAttributeValues.csv` - the distinct grouping values.
- `AttributeGroupMembershipPlan.csv` - the planned user-to-group mapping.

## Configuration

Both scripts use a `#region Configuration` block at the top.

### Export script

| Variable | Description |
|---|---|
| `$GroupName` | Source group to read members from |
| `$GroupingAttribute` | Attribute used to split users (the cost center attribute) |
| `$ExtensionAttributes` | Attributes to include in the export |
| `$OutputFileName` | Member export file name |
| `$UniqueValuesFileName` | Unique attribute values file name |

### Group buildout script

| Variable | Description |
|---|---|
| `$CsvFileName` | Input CSV from the export script |
| `$AttributeColumn` | CSV column that holds the grouping value |
| `$UserIdentityColumn` | CSV column that identifies the user |
| `$GroupNameTemplate` | Group name format. `{0}` is replaced with the cleaned attribute value |
| `$GroupPath` | OU where new groups are created |
| `$GroupScope` | AD group scope |
| `$GroupCategory` | AD group category |
| `$CreateMissingGroups` | Create groups that do not exist |
| `$SkipBlankAttributeValues` | Skip users with a blank attribute value |
| `$WhatIfPreference` | `$true` for a dry run, `$false` for live changes |

## How It Works

### Step 1: Export members

Set `$GroupName` and `$GroupingAttribute`, then run:

```powershell
.\Get-ADGroupMemberAttributes.ps1
```

This creates `GroupMembers.csv` and `UniqueAttributeValues.csv`.

### Step 2: Review the values

Open `UniqueAttributeValues.csv` to see the distinct values that will become groups. Open
`GroupMembers.csv` to confirm the grouping attribute is populated for each user.

### Step 3: Build the groups (dry run)

Confirm the configuration in the buildout script, leave `$WhatIfPreference = $true`, and run:

```powershell
.\Add-ADUsersToAttributeGroups.ps1
```

The script builds a group name for each value using the template, then previews every group
it would create and every user it would add. It also writes `AttributeGroupMembershipPlan.csv`.

Example group name:

```text
value = 123
group = APP-GROUP-PREFIX-123-Users
```

### Step 4: Review the plan

Open `AttributeGroupMembershipPlan.csv` and confirm users map to the expected groups. The
number of groups should match the row count in `UniqueAttributeValues.csv`.

### Step 5: Run live

Set:

```powershell
$WhatIfPreference = $false
```

Then run the buildout script again to create the groups and add the members.

## Reuse

The scripts are attribute-agnostic. To split by a different attribute, change
`$GroupingAttribute` in the export script and `$AttributeColumn` plus `$GroupNameTemplate`
in the buildout script. The same workflow applies to any single source group that needs to
be broken out into attribute-based groups.

## Notes

- The workflow is add-only. It does not remove users from any group.
- A missing target group is treated as "does not exist" and is created when enabled.
- Characters that are not letters, numbers, hyphens, or underscores are stripped from the
  attribute value before it is used in a group name.
- Keep `$WhatIfPreference = $true` until the plan has been reviewed.
- All files are expected to be in the same folder as the scripts.
