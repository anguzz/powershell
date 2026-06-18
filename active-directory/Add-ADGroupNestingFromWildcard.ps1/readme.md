# Add-ADGroupNestingFromWildcard.ps1

## Purpose
Adds all Active Directory groups matching a wildcard (e.g. `Test-Group*`) as members of a target group (e.g. `Target-Group`).

Useful for bulk group nesting when working with environments that use consistent naming conventions, enabling efficient organization and management of group membership at scale.

Common use cases include:
- Bulk onboarding or restructuring of groups  
- Standardizing group hierarchy  
- Preparing groups for downstream processes or integrations  
- Reducing manual effort when managing large sets of related groups  
---

## What It Does
- Finds groups using a name wildcard  
- Attempts to add each group to the target group  
- Skips on error (e.g. already a member)  
- Tracks successful additions  
- Supports PowerShell `-WhatIf` for safe preview  
- Creates a transcript log of all actions  

---

## Requirements
- Run on a domain-joined machine  
- ActiveDirectory module installed  
- Permissions to modify the target group  

---

## Usage
1. Update variables in script:
   - `$targetGroup`
   - `$wildcard`
2. Run with `-WhatIf` enabled for validation:
   ```powershell
   Add-ADGroupMember -Identity $targetGroup -Members $group -WhatIf
   ```

3. Remove `-WhatIf` for live execution
4. Review transcript log for full output

***

## Example

```powershell
.\Add-ADGroupNestingFromWildcard.ps1
```

***

## Output

* Console logging (processing + added + errors)
* Transcript log file:
  ```
  .\Add-ADGroupNesting_YYYYMMDD_HHMMSS.log
  ```

***

## Notes

* Creates **group-to-group nesting**
* Duplicate adds are safely ignored via error handling
* Recommended to validate with `-WhatIf` before execution
* Ensure groups are not already indirectly nested through other groups to avoid duplicate access paths


---

## Supporting Script

### Check-ADGroupGlobalMembership.ps1
Quick validation script to identify whether target groups are already nested in any **Global groups**.

Run this prior to bulk nesting to:
- Avoid duplicate or indirect membership paths  
- Confirm groups are not already part of higher-level group structures  

Outputs any groups that are members of Global groups for review.

---

### Design Note
This script is intentionally kept separate to maintain a clear separation of responsibilities:
- Validation logic (this script)  
- Execution logic (nesting script)  

While this check could be incorporated into the main script, doing so would:
- Increase complexity  
- Introduce additional branching logic  
- Raise the risk of errors during bulk operations  

Keeping validation separate helps ensure a cleaner, safer workflow:
**Validate → Review → Execute**