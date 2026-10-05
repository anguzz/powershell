# Export Conditional Access Policies

PowerShell scripts that export every Entra Conditional Access policy to a single CSV, with one row per policy and every setting flattened into columns.

Both scripts are **read-only**. They only send `GET` requests to Microsoft Graph and write a local CSV.

## Scripts

| Script | Description | Permissions |
|---|---|---|
| `Export-ConditionalAccessPolicies.ps1` | Exports policies with raw IDs | `Policy.Read.All` |
| `Export-ConditionalAccessPolicies-v2.ps1` | Exports policies and resolves IDs to names | `Policy.Read.All`, `Directory.Read.All` |

### What v2 resolves

Users, groups, roles, applications, service principals, and named locations.

- Resolved IDs appear as `Display Name (id)`.
- IDs that can't be resolved (for example, deleted objects) appear as `[Unresolved] (id)`.
- Special values such as `All`, `None`, and `AllTrusted` are unchanged.

## Requirements

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

## Usage

```powershell
Disconnect-MgGraph   # clears any cached session with other scopes
.\Export-ConditionalAccessPolicies-v2.ps1
```

If execution policy blocks the script:

```powershell
powershell -ExecutionPolicy Bypass -File .\Export-ConditionalAccessPolicies-v2.ps1
```

## Output

The CSV is saved in the current directory as:

```
ConditionalAccessPolicies_Full_yyyy-MM-dd_HHmmss.csv
```

- Nested settings become dot-notation columns, such as `conditions.users.excludeGroups`.
- Lists are separated by semicolons.
- Complex values are stored as compressed JSON.


## Optional (v2)

To resolve Terms of Use names or external tenant names, uncomment the matching scope, lookup, and `$ReferenceMap` entries:

- `Agreement.Read.All` resolves Terms of Use names.
- `CrossTenantInformation.ReadBasic.All` resolves external tenant names.