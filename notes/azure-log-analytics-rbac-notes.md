# Log Analytics / Sentinel Workbook RBAC 

## Context

Goal: Create  a group of users **open and read a workbook** and see its **underlying data**, without giving them the ability to create or modify anything. This walks through a custom "Workbook Reader" role, how it compares to the built-in **Security Reader** role, and the key detail about the `query` wildcard action. 
---

## 1. Custom Workbook Reader Role

A minimal custom role for reading workbooks and their data.

```json
{
    "properties": {
        "roleName": "Sentinel Workbook Reader",
        "description": "Allows for the reading of Sentinel/XDR workbooks",
        "assignableScopes": [
            "/subscriptions/<subscription-id>/resourceGroups/<resource-group>"
        ],
        "permissions": [
            {
                "actions": [
                    "Microsoft.Insights/Workbooks/Read",
                    "Microsoft.OperationalInsights/workspaces/read",
                    "Microsoft.OperationalInsights/workspaces/query/read",
                    "Microsoft.OperationalInsights/workspaces/query/*/read"
                ],
                "notActions": [],
                "dataActions": [],
                "notDataActions": []
            }
        ]
    }
}
```

### What each action does

| Action | Purpose |
|---|---|
| `Microsoft.Insights/Workbooks/Read` | Open/read the workbook resource itself (the layout and visuals). |
| `Microsoft.OperationalInsights/workspaces/read` | See that the Log Analytics workspace exists (get the workspace). |
| `Microsoft.OperationalInsights/workspaces/query/read` | **Launch/initiate** a query against the workspace. |
| `Microsoft.OperationalInsights/workspaces/query/*/read` | **Return the actual table data** the query pulls. This is the one that makes tiles populate instead of showing zeros. |

### The gotcha

- Having `query/read` **without** `query/*/read` means a user can *launch* a query but it returns **no rows** - the workbook shell loads but every tile shows `0`.
- Adding `query/*/read` is what actually lets them **see the underlying data**.
- Both of these live under **`actions`**, NOT `dataActions`. (Easy to get wrong - the legacy table-read permission is an Action.)

---

## 2. Wildcard vs. Per-Table Scoping

You can further lock down the role by adding table scoping.

The `query` action supports **table-level RBAC**:
```
Microsoft.OperationalInsights/workspaces/query/<TableName>/read
```

- **All tables (wildcard):**
  ```json
  "Microsoft.OperationalInsights/workspaces/query/*/read"
  ```
  Grants data read across **every** table in the workspace. Easiest to maintain; any workbook they're allowed to open will render fully.

- **Specific tables only (least privilege):**
  ```json
  "Microsoft.OperationalInsights/workspaces/query/DeviceEvents/read",
  "Microsoft.OperationalInsights/workspaces/query/DeviceFileEvents/read"
  ```
  Restricts data read to just the named tables. More secure, but you must update the role if a workbook later adds new data sources.

**Trade-off:** wildcard = less maintenance / broader access; per-table = tighter / more upkeep. Pick based on how strict least-privilege needs to be.

**Note:** table-level RBAC can interact with the workspace access control mode. Always test with a non-privileged account after changing.

---

## 3. Built-in Security Reader Role (for comparison)

```json
{
    "id": "/providers/Microsoft.Authorization/roleDefinitions/39bc4728-0917-49c7-9d2c-d95423bc2eb4",
    "properties": {
        "roleName": "Security Reader",
        "description": "Security Reader Role",
        "assignableScopes": [
            "/"
        ],
        "permissions": [
            {
                "actions": [
                    "Microsoft.Authorization/*/read",
                    "Microsoft.Insights/alertRules/read",
                    "Microsoft.operationalInsights/workspaces/*/read",
                    "Microsoft.Resources/deployments/*/read",
                    "Microsoft.Resources/subscriptions/resourceGroups/read",
                    "Microsoft.Security/*/read",
                    "Microsoft.IoTSecurity/*/read",
                    "Microsoft.Support/*/read",
                    "Microsoft.Security/iotDefenderSettings/packageDownloads/action",
                    "Microsoft.Security/iotDefenderSettings/downloadManagerActivation/action",
                    "Microsoft.Security/iotSensors/downloadResetPassword/action",
                    "Microsoft.IoTSecurity/defenderSettings/packageDownloads/action",
                    "Microsoft.IoTSecurity/defenderSettings/downloadManagerActivation/action",
                    "Microsoft.Management/managementGroups/read"
                ],
                "notActions": [],
                "dataActions": [],
                "notDataActions": []
            }
        ]
    }
}
```

### How it differs from the custom Workbook Reader

- **Much broader.** Security Reader is tenant-wide (`assignableScopes: "/"`) and grants read across Authorization, Security, IoT Security, Resources, Support, and management groups - not just one workspace.
- **Note the wildcard style:** `Microsoft.operationalInsights/workspaces/*/read`. The `*` sits **between** `workspaces` and `read`, so it covers the workspace's sub-resources (including query). This is a different shape than the custom role's explicit `workspaces/query/*/read`, but achieves broad workspace read.
- **Purpose:** Security Reader is a whole-of-tenant security visibility role. The custom Workbook Reader is a scalpel - one workspace, workbook + data read only.

### Takeaway on wildcard placement

The position of `*` matters:

| Pattern | Meaning |
|---|---|
| `.../workspaces/*/read` | Read all sub-resources of the workspace (broad). |
| `.../workspaces/query/*/read` | Read query results across all tables (data-plane). |
| `.../workspaces/query/<Table>/read` | Read query results for one specific table. |

---

## 4. What Read-Only Does NOT Grant

Even with the data-read wildcard added, a workbook reader still **cannot**:

- Create or edit workbooks / reports (needs a Creator/Contributor role).
- Browse the Sentinel Workbooks gallery (that needs `Microsoft.SecurityInsights/contenttemplates/read`). Direct workbook URLs still work; the gallery view will error.
- Modify analytics rules, incidents, or workspace settings.

So read only cleanly separates **consumers** (view workbook + data) from **authors** (need a creator role).

---

## 5. Quick Troubleshooting Checklist

1. **Workbook opens but tiles show 0** -> missing `query/*/read` (or the specific table). Add it under `actions`.
2. **Can't browse the Workbooks gallery** -> missing `contenttemplates/read`. Expected for a minimal reader role; use the direct URL.
3. **Change not taking effect** -> have the user **sign out and back in** so their token picks up the new permission.
4. **Editing the custom role** -> open IAM at the **scope in `assignableScopes`**, go to the **Roles** tab, and you need **Owner** or **User Access Administrator** to edit. Or update via PowerShell / CLI.

```powershell
$role = Get-AzRoleDefinition "Sentinel Workbook Reader"
$role.Actions.Add("Microsoft.OperationalInsights/workspaces/query/*/read")
Set-AzRoleDefinition -Role $role
```
