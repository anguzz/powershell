# Azure DevOps Effective Access Report

Read-only PowerShell collectors that export Azure DevOps permissions as one row per identity, resource, and permission. Reports include explicit allows, denies, inherited permissions, and `NotSet` values.

## Scripts

- `Export-AdoRepoReleasePermissions.ps1`: Git repositories, project-level Git permissions, and classic release pipelines.
- `Export-AdoResourceAccess.ps1`: Build/YAML pipelines, service connections, environments, variable groups, agent queues, project permissions, role assignments, Project Administrators, and optional PAT metadata.

Not included: branch-level ACL expansion, recursive group membership, or HR attributes.

## Read-only behavior

Both scripts use HTTP `GET` requests only. They do not send `POST`, `PUT`, `PATCH`, or `DELETE` requests. Output is written locally as CSV files and, optionally, an Excel workbook.

Verify the request methods:

```powershell
Select-String -Path .\Export-Ado*.ps1 -Pattern 'Method (Post|Put|Patch|Delete)'
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Network access to:
  - `dev.azure.com`
  - `vssps.dev.azure.com`
  - `vsrm.dev.azure.com`
- An organization-scoped Azure DevOps PAT with the required read permissions
- Optional: ImportExcel module for `.xlsx` output

```powershell
Install-Module ImportExcel -Scope CurrentUser
```

The PAT may require read access for Project and Team, Code, Graph, Identity, Release, Build, Service Connections, and the resource areas being audited. Environment inventory may require the Environment scope exposed by Azure DevOps. The optional `-IncludePats` mode requires elevated organization access and Token Administration permissions.

## Usage

Store the PAT in an environment variable instead of placing it in the script:

```powershell
$env:AZDO_PAT = "<your-pat>"
```

Test one project first:

```powershell
.\Export-AdoRepoReleasePermissions.ps1 `
    -Organization "contoso" `
    -ProjectName "Example Project"
```

Run the resource access collector:

```powershell
.\Export-AdoResourceAccess.ps1 `
    -Organization "contoso"
```

Create the optional Excel workbook:

```powershell
.\Export-AdoResourceAccess.ps1 `
    -Organization "contoso" `
    -CreateExcelWorkbook
```

Export PAT metadata when authorized:

```powershell
.\Export-AdoResourceAccess.ps1 `
    -Organization "contoso" `
    -IncludePats
```

## Parameters

- `-Organization`: Azure DevOps organization name. Can default to `$env:AZDO_ORG` if configured in the script.
- `-ProjectName`: Optional project name or ID. If omitted, all accessible projects are collected.
- `-Pat`: PAT value. Can default to `$env:AZDO_PAT` if configured in the script.
- `-BearerToken`: Entra access token. Defaults to `$env:AZDO_ACCESS_TOKEN`.
- `-OutputPath`: Output directory. Defaults to a timestamped folder beside the script.
- `-IncludePats`: Exports active PAT metadata. Available in the resource access script.
- `-CreateExcelWorkbook`: Creates a combined `.xlsx` file when ImportExcel is installed.

## Output

- `Repos_Permission.csv`: Repository and project-level Git permissions.
- `Release_Permission.csv`: Classic release pipeline permissions.
- `Resource_Permissions.csv`: Pipeline, service connection, environment, library, agent queue, and project ACLs.
- `Resource_Roles.csv`: Resource role assignments such as Administrator, User, and Reader.
- `Project_Administrators.csv`: Project Administrators roster used as an ownership proxy.
- `PersonalAccessTokens.csv`: PAT metadata when `-IncludePats` is used. PAT secret values are not exported.
- `Collection_Errors.csv`: API collection errors.

CSV files use BOM-free UTF-8. Empty result sets still include column headers.

## Permission values

- `Allow` / `Deny`: Explicit permission on the object.
- `InheritedAllow` / `InheritedDeny`: Permission inherited from a parent scope.
- `AllowedBySystem`: Effective access reported by Azure DevOps but not represented by an explicit ACE.
- `NotSet`: No permission is set for that identity and action.

Rows are emitted for every available permission action, including `NotSet`. This makes missing permissions visible instead of relying on missing rows.

## Ownership note

Azure DevOps does not provide a universal owner field for these resources. Project Administrators and resource-level Administrator roles are reported as ownership proxies, not confirmed owners.

## How it works

1. Enumerates accessible projects and resources.
2. Discovers Azure DevOps security namespaces.
3. Retrieves ACLs with extended and inherited permission data.
4. Decodes permission bitmasks against each namespace action.
5. Resolves Azure DevOps identity descriptors.
6. Retrieves role assignments for role-governed resources.
7. Writes local CSV files and an optional Excel workbook.

## Known limitations

- Branch-level repository ACLs are not expanded.
- Group membership is not recursively expanded, so an identity row may represent a group.
- Administrator roles are ownership proxies only.
- Large organization-wide runs may encounter HTTP 429 throttling; the scripts do not currently implement retry/backoff.
- HR attributes must be joined from another source.
- Some APIs used by Azure DevOps are preview endpoints and may change.

## Protect generated reports

Generated reports may contain names, email addresses, project names, resource IDs, group memberships, and permission assignments. Do not commit them to a public repository.

Recommended `.gitignore` entries:

```gitignore
ADO-Permissions-*/
ADO-ResourceAccess-*/
*.csv
*.xlsx
```
