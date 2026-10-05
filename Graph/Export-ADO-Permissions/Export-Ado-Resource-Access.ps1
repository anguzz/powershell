#Requires -Version 5.1
<#
.SYNOPSIS
Companion audit export for Azure DevOps resources NOT covered by
Export-AdoRepoReleasePermissions.ps1 (which handles repos + classic releases).

Covers:
  - Build / YAML pipeline permissions        (ACL model)
  - Service connection permissions           (ACL model)
  - Environment permissions                  (ACL model)
  - Library / variable group permissions     (ACL model)
  - Agent queue & pool permissions           (ACL model, via DistributedTask)
  - Project-level permissions                (ACL model)
  - Security ROLE assignments                (RBAC model - Administrator/User/Reader)
  - Project Administrators roster            (ownership proxy)
  - Personal Access Tokens                   (optional, org-admin only)

.DESCRIPTION
READ-ONLY. Issues HTTP GET requests exclusively. No POST/PUT/PATCH/DELETE.

Two distinct permission models are exported, because Azure DevOps uses both:

  1. ACL model  -> Resource_Permissions.csv
     Classic access control entries with allow/deny bitmasks and inheritance.
     Same shape as the repo/release report.

  2. ROLE model -> Resource_Roles.csv
     Service connections, environments, agent queues and variable groups are
     primarily governed by role assignments (Administrator / User / Reader)
     rather than ACLs. The Administrator role is the closest thing Azure DevOps
     has to an "owner" for these objects.

Both are needed for a complete picture. Reporting only ACLs would understate
access on service connections and environments.

.PARAMETER Organization
Azure DevOps organization name. 

.PARAMETER ProjectName
Optional. Limit to one project. Strongly recommended for first run.

.PARAMETER IncludePats
Also export Personal Access Tokens. Requires Project Collection Administrator
AND a PAT with "Token Administration (Read & manage)" scope. Off by default
because it needs elevated rights and enumerates every org user.

.PARAMETER CreateExcelWorkbook
Also produce a combined .xlsx (requires ImportExcel module).

.EXAMPLE
$env:AZDO_PAT = "<pat>"
.\Export-AdoResourceAccess.ps1 -Organization "My ORG" -ProjectName "My Project"

.EXAMPLE
.\Export-AdoResourceAccess.ps1 -CreateExcelWorkbook
#>
#>


[CmdletBinding()]
param(



    [string] $Organization = "",
    [string] $Pat = "", 
    [string]$ProjectName,
    [string]$BearerToken = $env:AZDO_ACCESS_TOKEN,
    [string]$OutputPath = (Join-Path $PSScriptRoot ("ADO-ResourceAccess-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
    [switch]$IncludePats,
    [switch]$CreateExcelWorkbook
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if (-not $Pat -and -not $BearerToken) { throw 'Provide -Pat, set AZDO_PAT, provide -BearerToken, or set AZDO_ACCESS_TOKEN.' }

$script:Headers = @{ Accept = 'application/json' }
if ($BearerToken) { $script:Headers.Authorization = "Bearer $BearerToken" }
else {
    $encodedPat = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$Pat"))
    $script:Headers.Authorization = "Basic $encodedPat"
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$script:IdentityCache = @{}
$script:GraphSubjectCache = @{}
$script:Errors = New-Object System.Collections.Generic.List[object]
$script:ProjectsById = @{}

function Invoke-AdoGet {
    param([Parameter(Mandatory)][string]$Uri,[string]$Area='REST',[switch]$SuppressErrorLog)
    try {
        $response = Invoke-WebRequest -Uri $Uri -Headers $script:Headers -Method Get -UseBasicParsing
        [pscustomobject]@{ Body=($response.Content | ConvertFrom-Json); Headers=$response.Headers }
    } catch {
        if (-not $SuppressErrorLog) {
            $script:Errors.Add([pscustomobject]@{TimeUtc=(Get-Date).ToUniversalTime().ToString('o');Area=$Area;Uri=$Uri;Error=$_.Exception.Message})
        }
        throw
    }
}

function Get-AdoPagedValue {
    param([Parameter(Mandatory)][string]$Uri,[string]$Area='REST')
    $items = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    do {
        $result = Invoke-AdoGet -Uri $next -Area $Area
        if ($null -ne $result.Body.value) { foreach ($item in @($result.Body.value)) { $items.Add($item) } }
        else { $items.Add($result.Body) }
        $token = $null
        try {
            if ($result.Headers -and $result.Headers.ContainsKey('x-ms-continuationtoken')) {
                $raw = $result.Headers['x-ms-continuationtoken']; if ($raw -is [array]) { $raw=$raw[0] }; $token=[string]$raw
            }
        } catch { $token=$null }
        if (-not $token -and $result.Body.PSObject.Properties.Name -contains 'continuationToken' -and $result.Body.continuationToken) { $token=[string]$result.Body.continuationToken }
        if ($token) {
            $base=$next -replace '([?&])continuationToken=[^&]*',''; $sep=if($base.Contains('?')){'&'}else{'?'}
            $next=$base+$sep+'continuationToken='+[Uri]::EscapeDataString($token)
        } else { $next=$null }
    } while ($next)
    $items.ToArray()
}

function Initialize-AdoGraphSubjectCache {
    Write-Host 'Loading Azure DevOps Graph identities...'
    foreach ($kind in @('users','groups')) {
        try {
            $uri="https://vssps.dev.azure.com/$Organization/_apis/graph/$kind`?api-version=7.1-preview.1"
            $subjects=@(Get-AdoPagedValue -Uri $uri -Area ("Graph-"+$kind))
            foreach ($s in $subjects) {
                if (-not $s.descriptor) { continue }
                $account=if($s.mailAddress){$s.mailAddress}elseif($s.principalName){$s.principalName}elseif($s.originId){$s.originId}else{$s.descriptor}
                $display=if($s.displayName){$s.displayName}else{$account}
                $script:GraphSubjectCache[[string]$s.descriptor]=[pscustomobject]@{
                    Descriptor=[string]$s.descriptor;Id=[string]$s.originId;AccountName=[string]$account;DisplayName=[string]$display
                    SubjectKind=if($kind -eq 'users'){'User'}else{'Group'}
                }
            }
            Write-Host ("  Graph {0}: {1}" -f $kind,$subjects.Count)
        } catch { Write-Warning ("Graph {0} inventory failed: {1}" -f $kind,$_.Exception.Message) }
    }
}

function Resolve-AdoIdentity {
    param([Parameter(Mandatory)][string]$Descriptor)
    if ($script:IdentityCache.ContainsKey($Descriptor)) { return $script:IdentityCache[$Descriptor] }
    if ($script:GraphSubjectCache.ContainsKey($Descriptor)) {
        $resolved=$script:GraphSubjectCache[$Descriptor]; $script:IdentityCache[$Descriptor]=$resolved; return $resolved
    }
    $resolved=[pscustomobject]@{Descriptor=$Descriptor;Id='';AccountName=$Descriptor;DisplayName=$Descriptor;SubjectKind='Unknown'}
    try {
        $encoded=[Uri]::EscapeDataString($Descriptor)
        $uri="https://vssps.dev.azure.com/$Organization/_apis/identities?descriptors=$encoded&queryMembership=None&api-version=7.1-preview.1"
        $i=@((Invoke-AdoGet -Uri $uri -Area 'IdentityFallback' -SuppressErrorLog).Body.value) | Select-Object -First 1
        if ($i) {
            $account=if($i.properties.Mail.'$value'){$i.properties.Mail.'$value'}elseif($i.properties.Account.'$value'){$i.properties.Account.'$value'}elseif($i.providerDisplayName){$i.providerDisplayName}elseif($i.customDisplayName){$i.customDisplayName}else{$Descriptor}
            $display=if($i.providerDisplayName){$i.providerDisplayName}elseif($i.customDisplayName){$i.customDisplayName}else{$account}
            $resolved=[pscustomobject]@{Descriptor=$Descriptor;Id=[string]$i.id;AccountName=[string]$account;DisplayName=[string]$display;SubjectKind=if($i.subjectKind){[string]$i.subjectKind}else{'Unknown'}}
        }
    } catch { }
    $script:IdentityCache[$Descriptor]=$resolved
    $resolved
}

function Test-Bit { param([long]$Mask,[long]$Bit) ($Bit -ne 0 -and (($Mask -band $Bit) -eq $Bit)) }
function Get-PermissionState {
    param([object]$Ace,[long]$Bit)
    $ea=[long]$Ace.allow;$ed=[long]$Ace.deny
    $ia=if($null -ne $Ace.extendedInfo.inheritedAllow){[long]$Ace.extendedInfo.inheritedAllow}else{0}
    $id=if($null -ne $Ace.extendedInfo.inheritedDeny){[long]$Ace.extendedInfo.inheritedDeny}else{0}
    $fa=if($null -ne $Ace.extendedInfo.effectiveAllow){[long]$Ace.extendedInfo.effectiveAllow}else{$ea -bor $ia}
    $fd=if($null -ne $Ace.extendedInfo.effectiveDeny){[long]$Ace.extendedInfo.effectiveDeny}else{$ed -bor $id}
    if(Test-Bit $ed $Bit){return [pscustomobject]@{Value='Deny';Inherited=$false}}
    if(Test-Bit $ea $Bit){return [pscustomobject]@{Value='Allow';Inherited=$false}}
    if(Test-Bit $id $Bit){return [pscustomobject]@{Value='InheritedDeny';Inherited=$true}}
    if(Test-Bit $ia $Bit){return [pscustomobject]@{Value='InheritedAllow';Inherited=$true}}
    if(Test-Bit $fd $Bit){return [pscustomobject]@{Value='Deny';Inherited=$null}}
    if(Test-Bit $fa $Bit){return [pscustomobject]@{Value='AllowedBySystem';Inherited=$null}}
    [pscustomobject]@{Value='NotSet';Inherited=$null}
}

Write-Host "Loading projects from '$Organization'..."
$projects=@(Get-AdoPagedValue -Uri "https://dev.azure.com/$Organization/_apis/projects?`$top=500&api-version=7.1" -Area Projects | Where-Object state -eq 'wellFormed')
if($ProjectName){$projects=@($projects|Where-Object{$_.name -eq $ProjectName -or $_.id -eq $ProjectName})}
if($projects.Count -eq 0){throw 'No matching Azure DevOps projects were found.'}
foreach($p in $projects){$script:ProjectsById[$p.id.ToString().ToLowerInvariant()]=$p.name}
Write-Host ("  {0} project(s) in scope." -f $projects.Count)
Initialize-AdoGraphSubjectCache

$resourceIndex=@{};$roleTargets=New-Object System.Collections.Generic.List[object]
function Add-Resource { param($ProjectId,$ProjectName,$Type,$ResourceId,$ResourceName)
    $resourceIndex[("{0}|{1}" -f $ProjectId,$ResourceId).ToLowerInvariant()]=[pscustomobject]@{Project=$ProjectName;Type=$Type;ResourceId=$ResourceId;Name=$ResourceName}
}
foreach($project in $projects){
    Write-Host "Inventory: $($project.name)";$projectId=$project.id.ToString()
    try{$defs=@(Get-AdoPagedValue "https://dev.azure.com/$Organization/$projectId/_apis/build/definitions?api-version=7.1" BuildDefinitions);foreach($d in $defs){Add-Resource $projectId $project.name pipeline $d.id $d.name};Write-Host("  Pipelines: {0}" -f $defs.Count)}catch{Write-Warning "  Pipeline inventory failed: $($_.Exception.Message)"}
    try{$eps=@(Get-AdoPagedValue "https://dev.azure.com/$Organization/$projectId/_apis/serviceendpoint/endpoints?api-version=7.1-preview.4" ServiceEndpoints);foreach($e in $eps){Add-Resource $projectId $project.name serviceconnection $e.id $e.name;$roleTargets.Add([pscustomobject]@{Project=$project.name;Type='serviceconnection';ResourceId=$e.id;ResourceName=$e.name;RoleScope='distributedtask.serviceendpointrole';RoleResourceId=("{0}_{1}" -f $projectId,$e.id);Extra=$e.type})};Write-Host("  Service connections: {0}" -f $eps.Count)}catch{Write-Warning "  Service connection inventory failed: $($_.Exception.Message)"}
    try{$envs=@(Get-AdoPagedValue "https://dev.azure.com/$Organization/$projectId/_apis/distributedtask/environments?`$top=500&api-version=7.1" Environments);foreach($e in $envs){Add-Resource $projectId $project.name environment $e.id $e.name;$roleTargets.Add([pscustomobject]@{Project=$project.name;Type='environment';ResourceId=$e.id;ResourceName=$e.name;RoleScope='distributedtask.environmentreferencerole';RoleResourceId=("{0}_{1}" -f $projectId,$e.id);Extra=''})};Write-Host("  Environments: {0}" -f $envs.Count)}catch{Write-Warning "  Environment inventory failed: $($_.Exception.Message)"}
    try{$vgs=@(Get-AdoPagedValue "https://dev.azure.com/$Organization/$projectId/_apis/distributedtask/variablegroups?api-version=7.1-preview.2" VariableGroups);foreach($v in $vgs){Add-Resource $projectId $project.name variablegroup $v.id $v.name;$roleTargets.Add([pscustomobject]@{Project=$project.name;Type='variablegroup';ResourceId=$v.id;ResourceName=$v.name;RoleScope='distributedtask.variablegrouprole';RoleResourceId=("{0}`${1}" -f $projectId,$v.id);Extra=''})};Write-Host("  Variable groups: {0}" -f $vgs.Count)}catch{Write-Warning "  Variable group inventory failed: $($_.Exception.Message)"}
    try{$queues=@(Get-AdoPagedValue "https://dev.azure.com/$Organization/$projectId/_apis/distributedtask/queues?api-version=7.1-preview.1" AgentQueues);foreach($q in $queues){Add-Resource $projectId $project.name agentqueue $q.id $q.name;$roleTargets.Add([pscustomobject]@{Project=$project.name;Type='agentqueue';ResourceId=$q.id;ResourceName=$q.name;RoleScope='distributedtask.agentqueuerole';RoleResourceId=("{0}_{1}" -f $projectId,$q.id);Extra=''})};Write-Host("  Agent queues: {0}" -f $queues.Count)}catch{Write-Warning "  Agent queue inventory failed: $($_.Exception.Message)"}
    Add-Resource $projectId $project.name project $projectId $project.name
}

Write-Host 'Discovering security namespaces...'
$allNamespaces=@((Invoke-AdoGet "https://dev.azure.com/$Organization/_apis/securitynamespaces?api-version=7.1" SecurityNamespaces).Body.value)
function Select-Namespace { param($Name,$Signature)
    $c=@($allNamespaces|Where-Object name -eq $Name);if($c.Count -eq 0){return $null};if($c.Count -eq 1){return $c[0]}
    if($Signature){$m=$c|Where-Object{@($_.actions|ForEach-Object name)-contains $Signature}|Select-Object -First 1;if($m){return $m}}
    $c|Sort-Object{@($_.actions).Count}-Descending|Select-Object -First 1
}
function Find-ResourceForToken { param($Token,$FallbackType)
    $gp='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';$guids=@([regex]::Matches($Token,$gp)|ForEach-Object{$_.Value.ToLowerInvariant()});$projectId=$null
    foreach($g in $guids){if($script:ProjectsById.ContainsKey($g)){$projectId=$g;break}};if(-not $projectId){return [pscustomobject]@{Project='';Type=$FallbackType;ResourceId=$Token;Name='';InScope=$false}}
    $segments=@($Token.Split('/')|Where-Object{$_});$candidates=New-Object System.Collections.Generic.List[string]
    for($i=$segments.Count-1;$i -ge 0;$i--){if($segments[$i] -match '^\d+$'-or $segments[$i] -match "^$gp$"){$candidates.Add($segments[$i].ToLowerInvariant())}}
    foreach($g in $guids){if($g -ne $projectId){$candidates.Add($g)}}
    foreach($c in $candidates){$key=("{0}|{1}" -f $projectId,$c);if($resourceIndex.ContainsKey($key)){$r=$resourceIndex[$key];return [pscustomobject]@{Project=$r.Project;Type=$r.Type;ResourceId=$Token;Name=$r.Name;InScope=$true}}}
    [pscustomobject]@{Project=$script:ProjectsById[$projectId];Type=$FallbackType;ResourceId=$Token;Name='';InScope=$true}
}
$plan=@(@{Name='Build';Type='pipeline';Signature='EditBuildDefinition'},@{Name='ServiceEndpoints';Type='serviceconnection'},@{Name='Environment';Type='environment'},@{Name='Library';Type='library'},@{Name='DistributedTask';Type='agentqueue'},@{Name='Project';Type='project'})
$permissionRows=New-Object System.Collections.Generic.List[object]
foreach($p in $plan){$ns=Select-Namespace $p.Name $p.Signature;if(-not $ns){Write-Warning "Namespace '$($p.Name)' not found.";continue};try{$acls=@((Invoke-AdoGet "https://dev.azure.com/$Organization/_apis/accesscontrollists/$($ns.namespaceId)?includeExtendedInfo=true&recurse=true&api-version=7.1" ("ACL-"+$p.Name)).Body.value)}catch{Write-Warning "ACL query failed for '$($p.Name)': $($_.Exception.Message)";continue};$kept=0
    foreach($acl in $acls){$r=Find-ResourceForToken ([string]$acl.token) $p.Type;if(-not $r.InScope){continue};$kept++;foreach($ap in $acl.acesDictionary.PSObject.Properties){$id=Resolve-AdoIdentity ([string]$ap.Value.descriptor);foreach($a in @($ns.actions|Sort-Object bit)){$s=Get-PermissionState $ap.Value ([long]$a.bit);$permissionRows.Add([pscustomobject][ordered]@{AccountName=$id.AccountName;DisplayName=$id.DisplayName;'ADO Project Name'=$r.Project;ResourceType=$r.Type;ResourceId=$r.ResourceId;ResourceName=$r.Name;SecurityNamespace=$ns.name;PermissionName=$a.displayName;EffectivePermission=$s.Value;IsPermissionInherited=$s.Inherited;Error=''})}}};Write-Host("ACLs [{0}]: {1} matched." -f $p.Name,$kept)}

Write-Host("Querying role assignments for {0} resource(s)..." -f $roleTargets.Count)
$roleRows=New-Object System.Collections.Generic.List[object]
foreach($t in $roleTargets){try{$u="https://dev.azure.com/$Organization/_apis/securityroles/scopes/$($t.RoleScope)/roleassignments/resources/$([Uri]::EscapeDataString($t.RoleResourceId))?api-version=7.1-preview.1";$as=@((Invoke-AdoGet $u ("Roles-"+$t.Type) -SuppressErrorLog).Body.value);foreach($a in $as){$roleRows.Add([pscustomobject][ordered]@{AccountName=if($a.identity.uniqueName){$a.identity.uniqueName}else{$a.identity.id};DisplayName=$a.identity.displayName;'ADO Project Name'=$t.Project;ResourceType=$t.Type;ResourceId=$t.ResourceId;ResourceName=$t.ResourceName;ResourceSubType=$t.Extra;RoleName=$a.role.displayName;RoleIsInherited=($a.access -eq 'inherited');AccessLevel=$a.access;IsOwnerProxy=($a.role.displayName -eq 'Administrator')})}}catch{}}

Write-Host 'Collecting Project Administrators...'
$adminRows=New-Object System.Collections.Generic.List[object]
try{$groups=@(Get-AdoPagedValue "https://vssps.dev.azure.com/$Organization/_apis/graph/groups?api-version=7.1-preview.1" GraphGroups);foreach($project in $projects){$escaped=[Management.Automation.WildcardPattern]::Escape("[$($project.name)]");$ags=@($groups|Where-Object{$_.displayName -eq 'Project Administrators'-and $_.principalName -like "*$escaped*"});foreach($g in $ags){try{$mu="https://vssps.dev.azure.com/$Organization/_apis/graph/memberships/$([Uri]::EscapeDataString($g.descriptor))?direction=down&api-version=7.1-preview.1";$members=@((Invoke-AdoGet $mu GraphMemberships).Body.value);foreach($m in $members){$descriptor=[string]$m.memberDescriptor;if([string]::IsNullOrWhiteSpace($descriptor)){continue};$id=Resolve-AdoIdentity $descriptor;$adminRows.Add([pscustomobject][ordered]@{'ADO Project Name'=$project.name;GroupName=$g.principalName;AccountName=$id.AccountName;DisplayName=$id.DisplayName;SubjectKind=$id.SubjectKind;MemberDescriptor=$descriptor;Note='Project Administrator - closest available owner proxy'})}}catch{Write-Warning("  Membership lookup failed for {0}: {1}" -f $g.principalName,$_.Exception.Message)}}}}catch{Write-Warning "Project Administrators collection failed: $($_.Exception.Message)"}
Write-Host("  {0} project administrator row(s)." -f $adminRows.Count)

$patRows=New-Object System.Collections.Generic.List[object]
if($IncludePats){Write-Host 'Collecting active PAT metadata...';try{$users=@(Get-AdoPagedValue "https://vssps.dev.azure.com/$Organization/_apis/graph/users?api-version=7.1-preview.1" GraphUsers);foreach($u in $users){try{$tu="https://vssps.dev.azure.com/$Organization/_apis/tokenadmin/personalaccesstokens/$([Uri]::EscapeDataString($u.descriptor))?api-version=7.1";$tokens=@((Invoke-AdoGet $tu TokenAdmin -SuppressErrorLog).Body.value);foreach($tk in $tokens){$patRows.Add([pscustomobject][ordered]@{AccountName=if($u.mailAddress){$u.mailAddress}else{$u.principalName};DisplayName=$u.displayName;TokenName=$tk.displayName;Scope=$tk.scope;ValidFrom=$tk.validFrom;ValidTo=$tk.validTo;IsValid=$tk.isValid;Source=$tk.source;ClientId=$tk.clientId;AuthorizationId=$tk.authorizationId})}}catch{}}}catch{Write-Warning "PAT collection failed: $($_.Exception.Message)"}}else{Write-Host 'Skipping PAT export (use -IncludePats to enable).'}

function Write-CsvNoBom { param($Data,[string]$Path,[string[]]$HeaderOrder)
    if($Data -and @($Data).Count -gt 0){$lines=$Data|ConvertTo-Csv -NoTypeInformation}elseif($HeaderOrder){$lines=@('"'+($HeaderOrder -join '","')+'"')}else{$lines=@()}
    [IO.File]::WriteAllLines($Path,[string[]]$lines,(New-Object Text.UTF8Encoding($false)))
}
Write-CsvNoBom $permissionRows.ToArray() (Join-Path $OutputPath 'Resource_Permissions.csv') @('AccountName','DisplayName','ADO Project Name','ResourceType','ResourceId','ResourceName','SecurityNamespace','PermissionName','EffectivePermission','IsPermissionInherited','Error')
Write-CsvNoBom $roleRows.ToArray() (Join-Path $OutputPath 'Resource_Roles.csv') @('AccountName','DisplayName','ADO Project Name','ResourceType','ResourceId','ResourceName','ResourceSubType','RoleName','RoleIsInherited','AccessLevel','IsOwnerProxy')
Write-CsvNoBom $adminRows.ToArray() (Join-Path $OutputPath 'Project_Administrators.csv') @('ADO Project Name','GroupName','AccountName','DisplayName','SubjectKind','MemberDescriptor','Note')
if($IncludePats){Write-CsvNoBom $patRows.ToArray() (Join-Path $OutputPath 'PersonalAccessTokens.csv') @('AccountName','DisplayName','TokenName','Scope','ValidFrom','ValidTo','IsValid','Source','ClientId','AuthorizationId')}
Write-CsvNoBom $script:Errors.ToArray() (Join-Path $OutputPath 'Collection_Errors.csv') @('TimeUtc','Area','Uri','Error')

if($CreateExcelWorkbook){if(Get-Module -ListAvailable ImportExcel){Import-Module ImportExcel;$xlsx=Join-Path $OutputPath 'ADO-Resource-Access.xlsx';$permissionRows.ToArray()|Export-Excel $xlsx -WorksheetName Resource_Permissions -TableName ResourcePermissions -AutoSize -FreezeTopRow -AutoFilter;$roleRows.ToArray()|Export-Excel $xlsx -WorksheetName Resource_Roles -TableName ResourceRoles -AutoSize -FreezeTopRow -AutoFilter;$adminRows.ToArray()|Export-Excel $xlsx -WorksheetName Project_Administrators -TableName ProjectAdmins -AutoSize -FreezeTopRow -AutoFilter;if($IncludePats){$patRows.ToArray()|Export-Excel $xlsx -WorksheetName PersonalAccessTokens -TableName Pats -AutoSize -FreezeTopRow -AutoFilter}}else{Write-Warning 'ImportExcel not installed. CSVs written; XLSX skipped.'}}

[pscustomobject]@{Organization=$Organization;Projects=$projects.Count;PermissionRows=$permissionRows.Count;RoleAssignmentRows=$roleRows.Count;ProjectAdminRows=$adminRows.Count;PatRows=if($IncludePats){$patRows.Count}else{'skipped'};Errors=$script:Errors.Count;OutputPath=$OutputPath}|Format-List
