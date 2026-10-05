#Requires -Version 5.1
<#
.SYNOPSIS
Exports repository and classic release permissions in a row-per-permission format.

.DESCRIPTION
Read-only collector. Only issues HTTP GET requests against Azure DevOps REST APIs.
Produces:
  - Repos_Permission.csv
  - Release_Permission.csv
  - Collection_Errors.csv
  - ADO-Repo-Release-Permissions.xlsx (only if ImportExcel is installed and -CreateExcelWorkbook is used)

Each identity/resource combination is expanded to one row per permission action, including
permissions that are NotSet, matching the format of the prior audit workbooks.


.PARAMETER Organization
Azure DevOps organization name. Defaults to $env:AZDO_ORG if not supplied.

.PARAMETER ProjectName
Optional. Limit collection to a single project (name or ID). Recommended for first test run.

.PARAMETER Pat
Personal Access Token. Defaults to the AZDO_PAT environment variable.

.PARAMETER BearerToken
Optional Entra ID access token, used instead of a PAT. Defaults to AZDO_ACCESS_TOKEN.

.PARAMETER OutputPath
Where output files are written. Defaults to a timestamped folder next to this script.

.PARAMETER CreateExcelWorkbook
If set, also builds a combined .xlsx workbook (requires the ImportExcel module).

.EXAMPLE
$env:AZDO_PAT = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
.\Export-AdoRepoReleasePermissions.ps1 -ProjectName "My Project"

.EXAMPLE
.\Export-AdoRepoReleasePermissions.ps1 -CreateExcelWorkbook
#>
[CmdletBinding()]
param(
    [string] $Organization = "", 
    [string] $Pat = "", 
    [string] $ProjectName,
    [string] $BearerToken = $env:AZDO_ACCESS_TOKEN,
    [string] $OutputPath = (Join-Path $PSScriptRoot ("ADO-Permissions-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [switch] $CreateExcelWorkbook
)


$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if (-not $Pat -and -not $BearerToken) {
    throw 'Provide -Pat, set the AZDO_PAT environment variable, provide -BearerToken, or set AZDO_ACCESS_TOKEN.'
}

# ---------------------------------------------------------------------------
# Auth headers
# ---------------------------------------------------------------------------
$script:Headers = @{ Accept = 'application/json' }
if ($BearerToken) {
    $script:Headers.Authorization = "Bearer $BearerToken"
} else {
    $encodedPat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
    $script:Headers.Authorization = "Basic $encodedPat"
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

$script:IdentityCache = @{}
$script:Errors = New-Object System.Collections.Generic.List[object]

# ---------------------------------------------------------------------------
# Core HTTP helpers
# ---------------------------------------------------------------------------
function Invoke-AdoGet {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [string]$Area = 'REST',
        # When set, failures are NOT written to Collection_Errors.csv. Used for
        # lookups that have a legitimate fallback path (e.g. Graph -> Identities).
        [switch]$SuppressErrorLog
    )
    try {
        $response = Invoke-WebRequest -Uri $Uri -Headers $script:Headers -Method Get -UseBasicParsing
        [pscustomobject]@{
            Body    = ($response.Content | ConvertFrom-Json)
            Headers = $response.Headers
        }
    } catch {
        if (-not $SuppressErrorLog) {
            $script:Errors.Add([pscustomobject]@{
                TimeUtc = (Get-Date).ToUniversalTime().ToString('o')
                Area    = $Area
                Uri     = $Uri
                Error   = $_.Exception.Message
            })
        }
        throw
    }
}

function Get-AdoPagedValue {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [string]$Area = 'REST'
    )
    $items = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    do {
        $result = Invoke-AdoGet -Uri $next -Area $Area

        if ($null -ne $result.Body.value) {
            foreach ($item in @($result.Body.value)) { $items.Add($item) }
        } else {
            $items.Add($result.Body)
        }

        $token = $null
        try {
            if ($result.Headers -and $result.Headers.ContainsKey('x-ms-continuationtoken')) {
                $rawToken = $result.Headers['x-ms-continuationtoken']
                if ($rawToken -is [array]) { $rawToken = $rawToken[0] }
                $token = [string]$rawToken
            }
        } catch {
            $token = $null
        }

        if (-not $token -and $result.Body.PSObject.Properties.Name -contains 'continuationToken' -and $result.Body.continuationToken) {
            $token = [string]$result.Body.continuationToken
        }

        if ($token) {
            $base = $next -replace '([?&])continuationToken=[^&]*', ''
            $separator = if ($base.Contains('?')) { '&' } else { '?' }
            $encodedToken = [System.Uri]::EscapeDataString($token)
            $next = $base + $separator + 'continuationToken=' + $encodedToken
        } else {
            $next = $null
        }
    } while ($next)
    # NOTE: intentionally using .ToArray() instead of @($items). Wrapping a
    # New-Object-created System.Collections.Generic.List[object] in @(...) can
    # throw "Argument types do not match" on some PowerShell 5.1 builds.
    # See: https://github.com/PowerShell/PowerShell/issues/27558
    $items.ToArray()
}

# ---------------------------------------------------------------------------
# Identity resolution
# ---------------------------------------------------------------------------
function Resolve-AdoIdentity {
    param([Parameter(Mandatory)][string]$Descriptor)

    if ($script:IdentityCache.ContainsKey($Descriptor)) { return $script:IdentityCache[$Descriptor] }

    $resolved = [pscustomobject]@{ Descriptor = $Descriptor; Id = ''; AccountName = ''; DisplayName = $Descriptor }

    try {
        # Graph only resolves modern descriptors (aad./vssgp./svc.). Legacy descriptors
        # (Microsoft.TeamFoundation.Identity;S-1-9-..., ServiceIdentity, ClaimsIdentity)
        # return 400/404 here by design, so failures are not logged -- the Identities
        # API fallback below handles them.
        $uri = "https://vssps.dev.azure.com/$Organization/_apis/graph/subjects/$([uri]::EscapeDataString($Descriptor))?api-version=7.1-preview.1"
        $g = (Invoke-AdoGet -Uri $uri -Area 'GraphSubject' -SuppressErrorLog).Body
        $account = if ($g.mailAddress) { $g.mailAddress }
                   elseif ($g.principalName) { $g.principalName }
                   elseif ($g.displayName) { $g.displayName }
                   else { '' }
        $resolved = [pscustomobject]@{
            Descriptor = $Descriptor; Id = $g.originId; AccountName = $account; DisplayName = $g.displayName
        }
    } catch {
        try {
            # Fallback for legacy descriptors. This one IS logged if it fails, because
            # at that point we genuinely could not resolve the identity.
            $uri = "https://vssps.dev.azure.com/$Organization/_apis/identities?descriptors=$([uri]::EscapeDataString($Descriptor))&queryMembership=None&api-version=7.1-preview.1"
            $i = @((Invoke-AdoGet -Uri $uri -Area 'IdentityFallback').Body.value)[0]
            $account = if ($i.properties.Mail.'$value') { $i.properties.Mail.'$value' }
                       elseif ($i.properties.Account.'$value') { $i.properties.Account.'$value' }
                       else { $i.providerDisplayName }
            $displayName = if ($i.providerDisplayName) { $i.providerDisplayName } else { $i.customDisplayName }
            $resolved = [pscustomobject]@{
                Descriptor = $Descriptor; Id = $i.id; AccountName = $account; DisplayName = $displayName
            }
        } catch { }
    }

    $script:IdentityCache[$Descriptor] = $resolved
    $resolved
}

# ---------------------------------------------------------------------------
# Permission bitmask decoding
# ---------------------------------------------------------------------------
function Test-Bit {
    param([long]$Mask, [long]$Bit)
    ($Bit -ne 0 -and (($Mask -band $Bit) -eq $Bit))
}

function Get-PermissionState {
    param([object]$Ace, [long]$Bit)

    $explicitAllow  = [long]$Ace.allow
    $explicitDeny   = [long]$Ace.deny
    $inheritedAllow = if ($null -ne $Ace.extendedInfo.inheritedAllow) { [long]$Ace.extendedInfo.inheritedAllow } else { 0 }
    $inheritedDeny  = if ($null -ne $Ace.extendedInfo.inheritedDeny) { [long]$Ace.extendedInfo.inheritedDeny } else { 0 }
    $effectiveAllow = if ($null -ne $Ace.extendedInfo.effectiveAllow) { [long]$Ace.extendedInfo.effectiveAllow } else { $explicitAllow -bor $inheritedAllow }
    $effectiveDeny  = if ($null -ne $Ace.extendedInfo.effectiveDeny) { [long]$Ace.extendedInfo.effectiveDeny } else { $explicitDeny -bor $inheritedDeny }

    if (Test-Bit $explicitDeny $Bit)   { return [pscustomobject]@{ Value = 'Deny';            Inherited = $false } }
    if (Test-Bit $explicitAllow $Bit)  { return [pscustomobject]@{ Value = 'Allow';           Inherited = $false } }
    if (Test-Bit $inheritedDeny $Bit)  { return [pscustomobject]@{ Value = 'InheritedDeny';   Inherited = $true } }
    if (Test-Bit $inheritedAllow $Bit) { return [pscustomobject]@{ Value = 'InheritedAllow';  Inherited = $true } }
    if (Test-Bit $effectiveDeny $Bit)  { return [pscustomobject]@{ Value = 'Deny';            Inherited = $null } }
    if (Test-Bit $effectiveAllow $Bit) { return [pscustomobject]@{ Value = 'AllowedBySystem'; Inherited = $null } }
    [pscustomobject]@{ Value = 'NotSet'; Inherited = $null }
}

# ---------------------------------------------------------------------------
# Resource lookup (maps a security token back to a friendly repo/release name)
# ---------------------------------------------------------------------------
function Find-Resource {
    param([string]$Token, [hashtable]$Resources, [string]$FallbackType)

    $lower = $Token.ToLowerInvariant()
    $candidates = foreach ($key in $Resources.Keys) {
        if ($lower.Contains($key)) {
            $priority = if ($Resources[$key].Type -eq 'projectGit') { 0 } else { 1 }
            [pscustomobject]@{ Key = $key; Length = $key.Length; Priority = $priority; Resource = $Resources[$key] }
        }
    }
    $best = $candidates | Sort-Object Priority, Length -Descending | Select-Object -First 1
    if ($best) { return $best.Resource }
    [pscustomobject]@{ Project = ''; Type = $FallbackType; Id = $Token; Name = ''; MatchKey = '' }
}

function Find-ReleaseResource {
    <#
    Release ACL tokens are hierarchical and may include a folder path, e.g.:
        <projectId>
        <projectId>/<definitionId>
        <projectId>/<folder>/<definitionId>          e.g. .../optimizely/2
        <projectId>/<folder>/<definitionId>/<envId>
    A plain substring match on the definition ID is unsafe (a definition ID of "2"
    matches almost anything), and matching "<projectId>/<definitionId>" fails whenever
    a folder segment sits in between. So match on TOKEN SEGMENTS instead.
    #>
    param([string]$Token, [hashtable]$Resources, [hashtable]$ProjectsById)

    # NOTE: @() is REQUIRED. A pipeline yielding a single item returns a scalar string,
    # and indexing a string ($segments[0]) returns a [System.Char], which has no
    # .ToLowerInvariant(). Project-level tokens have exactly one segment, so this path
    # is hit constantly.
    $segments = @($Token.Split('/') | Where-Object { $_ -ne '' })
    if ($segments.Count -eq 0) {
        return [pscustomobject]@{ Project = ''; Type = 'release'; Id = $Token; Name = ''; MatchKey = '' }
    }

    $projectId = $segments[0].ToLowerInvariant()
    $projectName = if ($ProjectsById.ContainsKey($projectId)) { $ProjectsById[$projectId] } else { '' }

    # Walk segments right-to-left looking for one that is a known definition ID for
    # this project. Right-to-left so environment-scoped tokens still resolve to their
    # parent pipeline rather than mis-matching an unrelated numeric segment.
    for ($i = $segments.Count - 1; $i -ge 1; $i--) {
        $candidateKey = ("{0}|{1}" -f $projectId, $segments[$i].ToLowerInvariant())
        if ($Resources.ContainsKey($candidateKey)) {
            $res = $Resources[$candidateKey]
            return [pscustomobject]@{
                Project  = $res.Project
                Type     = 'release'
                Id       = $Token       # emit the real ACL token, matching audit format
                Name     = $res.Name
                MatchKey = $candidateKey
            }
        }
    }

    # Project-level release ACL (no definition segment resolved).
    [pscustomobject]@{
        Project = $projectName; Type = 'release'; Id = $Token; Name = ''; MatchKey = $projectId
    }
}

# ---------------------------------------------------------------------------
# 1. Inventory projects, repositories, and classic release definitions
# ---------------------------------------------------------------------------
Write-Host "Loading projects from '$Organization'..."
$projects = @(
    Get-AdoPagedValue -Uri "https://dev.azure.com/$Organization/_apis/projects?`$top=100&api-version=7.1" -Area 'Projects' |
        Where-Object state -eq 'wellFormed'
)
if ($ProjectName) {
    $projects = @($projects | Where-Object { $_.name -eq $ProjectName -or $_.id -eq $ProjectName })
}
if ($projects.Count -eq 0) { throw 'No matching Azure DevOps projects were found.' }

$repoResources = @{}
$releaseResources = @{}

# projectId (lowercase) -> project name, used to label project-level release ACLs.
$script:ProjectsById = @{}
foreach ($p in $projects) { $script:ProjectsById[$p.id.ToString().ToLowerInvariant()] = $p.name }

foreach ($project in $projects) {
    Write-Host "Inventory: $($project.name)"

    try {
        $repos = @(Get-AdoPagedValue -Uri "https://dev.azure.com/$Organization/$($project.id)/_apis/git/repositories?includeHidden=true&api-version=7.1" -Area 'Repositories')
        foreach ($repo in $repos) {
            $key = $repo.id.ToString().ToLowerInvariant()
            $repoResources[$key] = [pscustomobject]@{
                Project = $project.name; Type = 'repo'; Id = "$($project.id)/$($repo.id)"; Name = $repo.name; MatchKey = $key
            }
        }
        # Project-level Git ACLs reference the project ID only (no repository ID present).
        $projectKey = $project.id.ToString().ToLowerInvariant()
        $repoResources[$projectKey] = [pscustomobject]@{
            Project = $project.name; Type = 'projectGit'; Id = $project.id; Name = ''; MatchKey = $projectKey
        }
    } catch {
        Write-Warning "Repository inventory failed for $($project.name)."
    }

    try {
        $defs = @(Get-AdoPagedValue -Uri "https://vsrm.dev.azure.com/$Organization/$($project.id)/_apis/release/definitions?`$expand=Environments&api-version=7.1" -Area 'ReleaseDefinitions')
        Write-Host ("  Repos: {0}   Classic release definitions: {1}" -f $repos.Count, $defs.Count)
        foreach ($def in $defs) {
            # Key on "<projectId>|<definitionId>" (pipe, NOT slash) because the real ACL
            # token may contain a folder segment between the two. Find-ReleaseResource
            # matches on token segments rather than substrings.
            $definitionKey = ("{0}|{1}" -f $project.id, $def.id).ToLowerInvariant()
            $releaseResources[$definitionKey] = [pscustomobject]@{
                Project = $project.name; Type = 'release'; Id = "$($project.id)/$($def.name)/$($def.id)"
                Name = $def.name; MatchKey = $definitionKey
            }
        }
        if ($defs.Count -eq 0) {
            Write-Host "  (No classic release pipelines in this project. If this project uses YAML multi-stage pipelines instead, release permissions will legitimately be empty.)" -ForegroundColor DarkYellow
        }
    } catch {
        Write-Warning "Classic release inventory failed for $($project.name): $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# 2. Discover the Git and Release Management security namespaces
# ---------------------------------------------------------------------------
Write-Host 'Discovering security namespaces...'
$namespaces = @((Invoke-AdoGet -Uri "https://dev.azure.com/$Organization/_apis/securitynamespaces?api-version=7.1" -Area 'SecurityNamespaces').Body.value)
$gitNs = $namespaces | Where-Object { $_.name -match '^Git Repositories$|Git' } | Select-Object -First 1


$releaseCandidates = @($namespaces | Where-Object { $_.name -match 'ReleaseManagement|Release Management' })
$releaseNs = $releaseCandidates |
    Where-Object { @($_.actions | ForEach-Object { $_.name }) -contains 'ViewReleaseDefinition' } |
    Select-Object -First 1

if (-not $releaseNs) {
    # Fallback: pick the candidate with the most actions (the real one is far richer).
    $releaseNs = $releaseCandidates | Sort-Object { @($_.actions).Count } -Descending | Select-Object -First 1
}

if (-not $gitNs) { throw 'Git Repositories security namespace was not found.' }
if (-not $releaseNs) {
    Write-Warning 'Release Management security namespace was not found. Release output will be empty.'
} else {
    Write-Host ("  Release namespace selected: {0} ({1} actions)" -f $releaseNs.namespaceId, @($releaseNs.actions).Count)
    if ($releaseCandidates.Count -gt 1) {
        Write-Host ("  (Note: {0} namespaces named 'ReleaseManagement' exist; chose the one exposing release definition permissions.)" -f $releaseCandidates.Count) -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# 3. Expand ACLs into one row per identity per permission
# ---------------------------------------------------------------------------
function Get-AclRows {
    param(
        [object]$Namespace,
        [hashtable]$Resources,
        [ValidateSet('Repo', 'Release')][string]$Mode
    )
    $rows = New-Object System.Collections.Generic.List[object]
    if (-not $Namespace) { return @() }

    $uri = "https://dev.azure.com/$Organization/_apis/accesscontrollists/$($Namespace.namespaceId)?includeExtendedInfo=true&recurse=true&api-version=7.1"
    $acls = @((Invoke-AdoGet -Uri $uri -Area "$Mode ACLs").Body.value)
    $selectedProjectIds = @($projects | ForEach-Object { $_.id.ToString().ToLowerInvariant() })

    Write-Host ("  {0}: {1} ACL(s) returned from namespace {2}" -f $Mode, $acls.Count, $Namespace.namespaceId)
    if ($Mode -eq 'Release' -and $acls.Count -gt 0) {
        $sample = @($acls | Select-Object -First 3 | ForEach-Object { $_.token })
        Write-Host ("  Sample release tokens: {0}" -f ($sample -join ' | ')) -ForegroundColor DarkGray
    }

    foreach ($acl in $acls) {
        $token = [string]$acl.token
        $tokenLower = $token.ToLowerInvariant()
        if (-not ($selectedProjectIds | Where-Object { $tokenLower.Contains($_) } | Select-Object -First 1)) { continue }

        $resource = if ($Mode -eq 'Repo') {
            Find-Resource -Token $token -Resources $Resources -FallbackType 'repo'
        } else {
            Find-ReleaseResource -Token $token -Resources $Resources -ProjectsById $script:ProjectsById
        }

        foreach ($aceProperty in $acl.acesDictionary.PSObject.Properties) {
            $ace = $aceProperty.Value
            $identity = Resolve-AdoIdentity -Descriptor ([string]$ace.descriptor)

            foreach ($action in @($Namespace.actions | Sort-Object bit)) {
                $state = Get-PermissionState -Ace $ace -Bit ([long]$action.bit)

                if ($Mode -eq 'Repo') {
                    $rows.Add([pscustomobject][ordered]@{
                        #Descriptor            = $identity.Descriptor # Not currently needed, but retained in case it is required later.
                        #Id                    = $identity.Id
                        AccountName           = $identity.AccountName
                        DisplayName           = $identity.DisplayName
                        'ADO Project Name'    = $resource.Project
                        ResourceType          = $resource.Type
                        ResourceId            = $resource.Id
                        ResourceName          = $resource.Name
                        PermissionName        = $action.displayName
                        EffectivePermission   = $state.Value
                        IsPermissionInherited = $state.Inherited
                        Error                 = ''
                    })
                } else {
                    $rows.Add([pscustomobject][ordered]@{
                        #Descriptor            = $identity.Descriptor
                        #Id                    = $identity.Id
                        AccountName           = $identity.AccountName
                        DisplayName           = $identity.DisplayName
                        ResourceType          = $resource.Type
                        ResourceId            = $resource.Id
                        ResourceName          = $resource.Name
                        PermissionName        = $action.displayName
                        EffectivePermission   = $state.Value
                        IsPermissionInherited = $state.Inherited
                        Error                 = ''
                    })
                }
            }
        }
    }
    # See note in Get-AdoPagedValue above re: @() vs .ToArray() on List[object].
    $rows.ToArray()
}

Write-Host 'Expanding repository permissions...'
$repoRows = @(Get-AclRows -Namespace $gitNs -Resources $repoResources -Mode Repo)

Write-Host 'Expanding classic release permissions...'
$releaseRows = @(Get-AclRows -Namespace $releaseNs -Resources $releaseResources -Mode Release)

if ($releaseRows.Count -eq 0) {
    Write-Warning 'Release_Permission returned 0 rows. Common, expected causes:'
    Write-Warning '  1. The org uses YAML multi-stage pipelines instead of Classic Release pipelines.'
    Write-Warning '  2. No Classic Release definitions exist (check the per-project counts logged above).'
    Write-Warning '  3. The PAT lacks the Release (Read) scope.'
    Write-Warning 'An empty CSV will still be written (header row only).'
}

# ---------------------------------------------------------------------------
# 4. Write output
# ---------------------------------------------------------------------------
$repoCsv    = Join-Path $OutputPath 'Repos_Permission.csv'
$releaseCsv = Join-Path $OutputPath 'Release_Permission.csv'
$errorCsv   = Join-Path $OutputPath 'Collection_Errors.csv'

# PowerShell 5.1's "Export-Csv -Encoding UTF8" always writes a UTF-8 BOM, which shows
# up as "" at the start of the file in some editors/parsers. Write BOM-free UTF-8
# instead via ConvertTo-Csv + .NET, which behaves consistently everywhere.
function Write-CsvNoBom {
    param($Data, [string]$Path, [string[]]$HeaderOrder)

    if ($Data -and @($Data).Count -gt 0) {
        $lines = $Data | ConvertTo-Csv -NoTypeInformation
    } elseif ($HeaderOrder) {
        # Preserve the expected column headers even when there are zero rows,
        # so the audit deliverable still has a usable schema.
        $lines = @('"' + ($HeaderOrder -join '","') + '"')
    } else {
        $lines = @()
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, [string[]]$lines, $utf8NoBom)
}

$repoHeaders = @(<#'Descriptor','Id',#> 'AccountName','DisplayName','ADO Project Name','ResourceType','ResourceId','ResourceName','PermissionName','EffectivePermission','IsPermissionInherited','Error')
$releaseHeaders = @(<#'Descriptor','Id',#>'AccountName','DisplayName','ResourceType','ResourceId','ResourceName','PermissionName','EffectivePermission','IsPermissionInherited','Error')
$errorHeaders = @('TimeUtc','Area','Uri','Error')

Write-CsvNoBom -Data $repoRows      -Path $repoCsv    -HeaderOrder $repoHeaders
Write-CsvNoBom -Data $releaseRows   -Path $releaseCsv -HeaderOrder $releaseHeaders
Write-CsvNoBom -Data $script:Errors -Path $errorCsv   -HeaderOrder $errorHeaders

if ($CreateExcelWorkbook) {
    if (Get-Module -ListAvailable ImportExcel) {
        Import-Module ImportExcel
        $xlsx = Join-Path $OutputPath 'ADO-Repo-Release-Permissions.xlsx'
        $repoRows    | Export-Excel -Path $xlsx -WorksheetName 'Repos_Permission'    -TableName 'ReposPermission'   -AutoSize -FreezeTopRow -AutoFilter
        $releaseRows | Export-Excel -Path $xlsx -WorksheetName 'Release_Permission'  -TableName 'ReleasePermission' -AutoSize -FreezeTopRow -AutoFilter
        if ($script:Errors.Count -gt 0) {
            $script:Errors | Export-Excel -Path $xlsx -WorksheetName 'Collection_Errors' -TableName 'CollectionErrors' -AutoSize -FreezeTopRow
        }
    } else {
        Write-Warning 'ImportExcel is not installed. CSV files were created, but the XLSX workbook was skipped.'
        Write-Warning 'Install with: Install-Module ImportExcel -Scope CurrentUser'
    }
}

[pscustomobject]@{
    Organization   = $Organization
    Projects       = $projects.Count
    RepositoryRows = $repoRows.Count
    ReleaseRows    = $releaseRows.Count
    Errors         = $script:Errors.Count
    OutputPath     = $OutputPath
} | Format-List
