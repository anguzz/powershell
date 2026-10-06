<#
.SYNOPSIS
    Exports complete Entra Conditional Access policy configurations to CSV,
    with referenced IDs resolved to display names.

.DESCRIPTION
    The script:
      1. Retrieves every Conditional Access policy.
      2. Retrieves each complete policy object individually.
      3. Resolves referenced IDs (users, groups, roles, apps,
         service principals, named locations) to "Display Name (id)".
      4. Recursively flattens all nested properties.
      5. Converts simple arrays to semicolon-separated values.
      6. Converts complex arrays to compressed JSON.
      7. Builds a combined set of columns across all policies.
      8. Exports one row per policy to a single CSV file.

    Special values such as All, None, GuestsOrExternalUsers, Office365,
    and AllTrusted are left unchanged. IDs that cannot be resolved
    (deleted objects, missing permissions) show as "[Unresolved] (id)".

.NOTES
    Graph permissions (read-only):
      Policy.Read.All     - CA policies, named locations
      Directory.Read.All  - users, groups, roles, service principals

    Optional (currently disabled):
      Agreement.Read.All                   - Terms of Use names
      CrossTenantInformation.ReadBasic.All - external tenant names

    This script is read-only against Microsoft Graph.
    It only sends GET requests and creates a local CSV file.

    Microsoft Graph PowerShell SDK is required:
      Install-Module Microsoft.Graph -Scope CurrentUser
#>

# Stop if a terminating error occurs
$ErrorActionPreference = "Stop"

# Connect using read-only permissions
Connect-MgGraph `
    -Scopes @(
        "Policy.Read.All",
        "Directory.Read.All"
        # "Agreement.Read.All"                   - enable if Terms of Use is used
        # "CrossTenantInformation.ReadBasic.All" - enable if external tenants are targeted
    ) `
    -NoWelcome

# Create the output file in the current PowerShell directory
$Date = Get-Date -Format "yyyy-MM-dd_HHmmss"

$ExportPath = Join-Path `
    -Path (Get-Location).Path `
    -ChildPath "ConditionalAccessPolicies_Full.csv" #date can be added here if desired, e.g., "ConditionalAccessPolicies_Full_$Date.csv"

#region Flattening

function ConvertTo-FlatHashtable {
    <#
    .SYNOPSIS
        Recursively flattens a nested object.

    .DESCRIPTION
        Nested objects become dot-separated property names.
        Simple arrays become semicolon-separated values.
        Complex arrays are preserved as compressed JSON.
    #>

    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject,

        [string]$Prefix = ""
    )

    $FlattenedData = [ordered]@{}

    function Add-FlattenedValue {
        param(
            [AllowNull()]
            [object]$Value,

            [string]$Path
        )

        # Preserve null properties
        if ($null -eq $Value) {
            if (-not [string]::IsNullOrWhiteSpace($Path)) {
                $FlattenedData[$Path] = $null
            }

            return
        }

        # Handle dictionaries returned by Invoke-MgGraphRequest
        if ($Value -is [System.Collections.IDictionary]) {
            foreach ($Key in $Value.Keys) {
                $ChildPath = if ([string]::IsNullOrWhiteSpace($Path)) {
                    [string]$Key
                }
                else {
                    "$Path.$Key"
                }

                Add-FlattenedValue -Value $Value[$Key] -Path $ChildPath
            }

            return
        }

        # Handle arrays and other enumerable collections
        if (
            $Value -is [System.Collections.IEnumerable] -and
            $Value -isnot [string]
        ) {
            $Items = @($Value)

            # Preserve empty arrays
            if ($Items.Count -eq 0) {
                $FlattenedData[$Path] = ""
                return
            }

            # Determine whether every array item is a simple value
            $AllItemsAreSimple = $true

            foreach ($Item in $Items) {
                if (
                    $null -ne $Item -and
                    $Item -isnot [string] -and
                    $Item -isnot [ValueType]
                ) {
                    $AllItemsAreSimple = $false
                    break
                }
            }

            if ($AllItemsAreSimple) {
                $FlattenedData[$Path] = $Items -join "; "
            }
            else {
                # -InputObject keeps single-item arrays wrapped in [ ]
                $FlattenedData[$Path] = ConvertTo-Json `
                    -InputObject $Items `
                    -Depth 100 `
                    -Compress
            }

            return
        }

        # Handle PowerShell objects with nested properties
        $ObjectProperties = @(
            $Value.PSObject.Properties |
            Where-Object {
                $_.MemberType -in @(
                    "NoteProperty",
                    "Property",
                    "AliasProperty",
                    "ScriptProperty"
                )
            }
        )

        if (
            $ObjectProperties.Count -gt 0 -and
            $Value -isnot [string] -and
            $Value -isnot [ValueType]
        ) {
            foreach ($Property in $ObjectProperties) {
                $ChildPath = if ([string]::IsNullOrWhiteSpace($Path)) {
                    $Property.Name
                }
                else {
                    "$Path.$($Property.Name)"
                }

                Add-FlattenedValue -Value $Property.Value -Path $ChildPath
            }

            return
        }

        # Save the final property value
        if (-not [string]::IsNullOrWhiteSpace($Path)) {
            $FlattenedData[$Path] = $Value
        }
    }

    Add-FlattenedValue -Value $InputObject -Path $Prefix

    return $FlattenedData
}

#endregion

#region ID resolution (all GET requests)

$GraphBase = "https://graph.microsoft.com/v1.0"
$GuidPattern = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
$ResolveCache = @{}

function Get-GraphCollection {
    <#
    .SYNOPSIS
        Retrieves every item from a Graph collection, following paging.
        Returns an empty array if access is denied.
    #>
    param([string]$Uri)

    $Items = @()

    try {
        do {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $Uri

            if ($Response.value) {
                $Items += @($Response.value)
            }

            $Uri = $Response.'@odata.nextLink'
        }
        while ($Uri)
    }
    catch {
        Write-Warning "Could not read $Uri : $($_.Exception.Message)"
    }

    return $Items
}

function Resolve-GraphObject {
    <#
    .SYNOPSIS
        Resolves one ID to "Display Name (id)". Results are cached.
    #>
    param(
        [string]$Kind,
        [string]$Id
    )

    $CacheKey = "$Kind|$Id"

    if ($ResolveCache.ContainsKey($CacheKey)) {
        return $ResolveCache[$CacheKey]
    }

    $Name = $null

    try {
        switch ($Kind) {
            "User" {
                $Result = Invoke-MgGraphRequest -Method GET `
                    -Uri "$GraphBase/users/$($Id)?`$select=displayName,userPrincipalName"
                $Name = "$($Result.displayName) <$($Result.userPrincipalName)>"
            }
            "Group" {
                $Result = Invoke-MgGraphRequest -Method GET `
                    -Uri "$GraphBase/groups/$($Id)?`$select=displayName"
                $Name = $Result.displayName
            }
            "Role" {
                $Name = $RoleMap[$Id]
            }
            "Location" {
                $Name = $LocationMap[$Id]
            }
            "Agreement" {
                $Name = $AgreementMap[$Id]
            }
            "Application" {
                # CA application lists contain appId values, not object IDs
                $Result = Invoke-MgGraphRequest -Method GET `
                    -Uri "$GraphBase/servicePrincipals?`$filter=appId eq '$Id'&`$select=displayName"
                if ($Result.value) {
                    $Name = @($Result.value)[0].displayName
                }
            }
            "ServicePrincipal" {
                $Result = Invoke-MgGraphRequest -Method GET `
                    -Uri "$GraphBase/servicePrincipals/$($Id)?`$select=displayName"
                $Name = $Result.displayName
            }
            "Tenant" {
                $Result = Invoke-MgGraphRequest -Method GET `
                    -Uri "$GraphBase/tenantRelationships/findTenantInformationByTenantId(tenantId='$Id')"
                $Name = $Result.displayName
            }
        }
    }
    catch {
        # Deleted object, missing permission, or not found
        $Name = $null
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = "[Unresolved]"
    }

    $Resolved = "$Name ($Id)"
    $ResolveCache[$CacheKey] = $Resolved

    return $Resolved
}

function Get-NestedValue {
    param(
        [System.Collections.IDictionary]$Object,
        [string]$Path
    )

    $Current = $Object

    foreach ($Segment in $Path.Split(".")) {
        if ($null -eq $Current -or $Current -isnot [System.Collections.IDictionary]) {
            return $null
        }

        $Current = $Current[$Segment]
    }

    return $Current
}

# Policy locations that hold ID references, and the object type they point to
$ReferenceMap = @(
    @{ Parent = "conditions.users";              Keys = "includeUsers", "excludeUsers";                         Kind = "User" }
    @{ Parent = "conditions.users";              Keys = "includeGroups", "excludeGroups";                       Kind = "Group" }
    @{ Parent = "conditions.users";              Keys = "includeRoles", "excludeRoles";                         Kind = "Role" }
    @{ Parent = "conditions.applications";       Keys = "includeApplications", "excludeApplications";           Kind = "Application" }
    @{ Parent = "conditions.clientApplications"; Keys = "includeServicePrincipals", "excludeServicePrincipals"; Kind = "ServicePrincipal" }
    @{ Parent = "conditions.locations";          Keys = "includeLocations", "excludeLocations";                 Kind = "Location" }

    # Enable with Agreement.Read.All
    # @{ Parent = "grantControls"; Keys = @("termsOfUse"); Kind = "Agreement" }

    # Enable with CrossTenantInformation.ReadBasic.All
    # @{ Parent = "conditions.users.includeGuestsOrExternalUsers.externalTenants"; Keys = @("members"); Kind = "Tenant" }
    # @{ Parent = "conditions.users.excludeGuestsOrExternalUsers.externalTenants"; Keys = @("members"); Kind = "Tenant" }
)

function Resolve-PolicyReferences {
    <#
    .SYNOPSIS
        Replaces GUID references in a policy with "Display Name (id)".
        Non-GUID values such as All, None, Office365 are left unchanged.
    #>
    param([System.Collections.IDictionary]$Policy)

    foreach ($Reference in $ReferenceMap) {
        $Parent = Get-NestedValue -Object $Policy -Path $Reference.Parent

        if ($Parent -isnot [System.Collections.IDictionary]) {
            continue
        }

        foreach ($Key in $Reference.Keys) {
            if ($null -eq $Parent[$Key]) {
                continue
            }

            $Parent[$Key] = @(
                foreach ($Value in @($Parent[$Key])) {
                    if ([string]$Value -match $GuidPattern) {
                        Resolve-GraphObject -Kind $Reference.Kind -Id ([string]$Value)
                    }
                    else {
                        $Value
                    }
                }
            )
        }
    }
}

#endregion

try {
    #region Lookup tables

    Write-Host "Loading lookup tables..."

    # Roles: CA uses role template IDs. Map both id and templateId.
    $RoleMap = @{}
    foreach ($Role in Get-GraphCollection "$GraphBase/roleManagement/directory/roleDefinitions?`$select=id,templateId,displayName") {
        $RoleMap[[string]$Role.id] = $Role.displayName

        if ($Role.templateId) {
            $RoleMap[[string]$Role.templateId] = $Role.displayName
        }
    }

    # Named locations
    $LocationMap = @{}
    foreach ($Location in Get-GraphCollection "$GraphBase/identity/conditionalAccess/namedLocations") {
        $LocationMap[[string]$Location.id] = $Location.displayName
    }

    # Terms of use agreements (enable with Agreement.Read.All)
    $AgreementMap = @{}
    # foreach ($Agreement in Get-GraphCollection "$GraphBase/identityGovernance/termsOfUse/agreements?`$select=id,displayName") {
    #     $AgreementMap[[string]$Agreement.id] = $Agreement.displayName
    # }

    Write-Host "Roles loaded: $($RoleMap.Count)"
    Write-Host "Named locations loaded: $($LocationMap.Count)"

    #endregion

    #region Retrieve policies

    Write-Host "Retrieving Conditional Access policy list..."

    $PolicyList = Get-GraphCollection "$GraphBase/identity/conditionalAccess/policies"

    if ($PolicyList.Count -eq 0) {
        Write-Warning "No Conditional Access policies were returned."
        return
    }

    Write-Host "Policies found: $($PolicyList.Count)"
    Write-Host "Retrieving complete policy objects and resolving IDs..."

    $FlattenedPolicies = @()
    $AllColumnNames = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $CurrentPolicy = 0

    foreach ($PolicySummary in $PolicyList) {
        $CurrentPolicy++

        Write-Host "[$CurrentPolicy/$($PolicyList.Count)] $($PolicySummary.displayName)"

        # Retrieve each complete policy object individually
        $CompletePolicy = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "$GraphBase/identity/conditionalAccess/policies/$($PolicySummary.id)"

        # Replace referenced IDs with "Display Name (id)"
        Resolve-PolicyReferences -Policy $CompletePolicy

        # Flatten every property returned by Graph
        $FlattenedPolicy = ConvertTo-FlatHashtable -InputObject $CompletePolicy

        $FlattenedPolicies += $FlattenedPolicy

        # Build a complete list of columns across all policies
        foreach ($ColumnName in $FlattenedPolicy.Keys) {
            [void]$AllColumnNames.Add($ColumnName)
        }
    }

    #endregion

    #region Column ordering

    # Keep the main policy fields at the beginning
    $PreferredColumns = @(
        "displayName",
        "id",
        "state",
        "templateId",
        "createdDateTime",
        "modifiedDateTime",
        "deletedDateTime"
    )

    $FirstColumns = @(
        $PreferredColumns |
        Where-Object { $AllColumnNames.Contains($_) }
    )

    $RemainingColumns = @(
        $AllColumnNames |
        Where-Object {
            $_ -notin $PreferredColumns -and
            $_ -notlike "@odata.*" -and
            $_ -notlike "@microsoft.graph.*"
        } |
        Sort-Object
    )

    # Keep Graph metadata columns at the end
    $MetadataColumns = @(
        $AllColumnNames |
        Where-Object {
            $_ -like "@odata.*" -or
            $_ -like "@microsoft.graph.*"
        } |
        Sort-Object
    )

    $OrderedColumns = @(
        $FirstColumns
        $RemainingColumns
        $MetadataColumns
    )

    #endregion

    #region Export

    # Every row gets every column so Export-Csv doesn't drop any
    $CsvRows = foreach ($FlattenedPolicy in $FlattenedPolicies) {
        $Row = [ordered]@{}

        foreach ($ColumnName in $OrderedColumns) {
            if ($FlattenedPolicy.Contains($ColumnName)) {
                $Row[$ColumnName] = $FlattenedPolicy[$ColumnName]
            }
            else {
                $Row[$ColumnName] = $null
            }
        }

        [PSCustomObject]$Row
    }

    $CsvRows |
        Sort-Object displayName |
        Export-Csv `
            -Path $ExportPath `
            -NoTypeInformation `
            -Encoding UTF8 `
            -Force

    if (-not (Test-Path -LiteralPath $ExportPath)) {
        throw "Export-Csv completed, but the file was not found."
    }

    $ExportedFile = Get-Item -LiteralPath $ExportPath

    $UnresolvedCount = @(
        $ResolveCache.Values | Where-Object { $_ -like "`[Unresolved`]*" }
    ).Count

    Write-Host ""
    Write-Host "Export complete."
    Write-Host "Policies exported: $($PolicyList.Count)"
    Write-Host "IDs resolved: $($ResolveCache.Count - $UnresolvedCount)"
    Write-Host "IDs unresolved: $UnresolvedCount"
    Write-Host "CSV columns: $($OrderedColumns.Count)"
    Write-Host "CSV size: $([math]::Round($ExportedFile.Length / 1KB, 2)) KB"
    Write-Host "CSV file: $($ExportedFile.FullName)"

    #endregion
}
catch {
    Write-Error "Conditional Access export failed: $($_.Exception.Message)"
}