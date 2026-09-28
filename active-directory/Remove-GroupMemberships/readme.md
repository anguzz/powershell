
# Active Directory Group Membership removal Scripts

A collection of PowerShell scripts for bulk Active Directory group membership auditing and removal. These scripts support CSV based user processing, test/dry run validation, targeted group membership removal, exception handling, and CSV reporting to help safely manage group memberships at scale.

# Remove-GroupMemberships

Removes direct Active Directory group memberships for users listed in a CSV file.

The script reads a single-column `input.csv` containing user UPNs and processes each account.

- **Test mode**: Reports which group memberships would be removed.
- **Remove mode**: Removes direct group memberships and exports the results to a CSV.
- Primary/default groups (for example, `Domain Users`) are automatically excluded.

## Input CSV

```csv
UPN
user1@contoso.com
user2@contoso.com
```

## Usage

```powershell
# Test only
.\Remove-GroupMemberships.ps1
```

```powershell
# Remove memberships
.\Remove-GroupMemberships.ps1 -Mode Remove
```

---

# Remove-SpecificGroupMembership

Removes users from a specific Active Directory group.

The script reads a single-column `input.csv` containing user UPNs and checks whether each user is a member of the group defined in the script.

- **Test mode**: Reports users who would be removed from the group.
- **Remove mode**: Removes the membership.
- Users who are not members are skipped.
- Results are exported to a CSV.

## Input CSV

```csv
UPN
user1@contoso.com
user2@contoso.com
```

## Example Script Setting

```powershell
$GroupName = 'VPN Users'
```

## Usage

```powershell
# Test only
.\Remove-SpecificGroupMembership.ps1
```

```powershell
# Remove membership
.\Remove-SpecificGroupMembership.ps1 -Mode Remove
```

---

# Example Output

```text
User: user1@contoso.com
  [TEST] Would remove: Application Users
  [TEST] Would remove: Remote Access Users

User: user2@contoso.com
  No direct group memberships found.

User: user3@contoso.com
  [SKIP - EXCEPTION] Protected Group
  [TEST] Would remove: Server Administrators

User: user4@contoso.com
  Not a member of target group. Skipping.

Mode: Test

Results exported to:
C:\Scripts\Reports\GroupMembershipRemoval_YYYYMMDD_HHMMSS.csv

No memberships were removed. Run with -Mode Remove to apply the changes.
```

## Features

- Supports **Test** and **Remove** modes
- Processes users from CSV input
- Exports detailed results to CSV
- Preserves primary/default group memberships
- Supports configurable exception groups
- Provides clear console output and auditing information

## Disclaimer

Review and test all scripts in a non-production environment before use. Always validate the users, groups, and exception lists being targeted before running in **Remove** mode.
