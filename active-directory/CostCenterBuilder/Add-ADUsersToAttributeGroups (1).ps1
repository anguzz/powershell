<#
.SYNOPSIS
Creates attribute-based AD groups from a CSV export and adds users to the matching group.

.DESCRIPTION
Reads the CSV produced by Get-ADGroupMemberAttributes.ps1, takes a configured attribute
value from each row (for example, a cost center value), builds a target group name from a
template, creates the group if it does not exist, and adds the user to the matching group.

Group name format is controlled by $GroupNameTemplate, where {0} is replaced with the
cleaned attribute value.

Example:
attribute value = 123
Group created/used = APP-GROUP-PREFIX-123-Users

Dry run is controlled by $WhatIfPreference in the Configuration section.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param()

#region Configuration

# Input CSV (produced by the export script) and output plan file.
$CsvFileName        = "GroupMembers.csv"
$PlanOutputFileName = "AttributeGroupMembershipPlan.csv"

# CSV column that holds the grouping value and the column that identifies the user.
$AttributeColumn    = "extensionAttributeX"
$UserIdentityColumn = "SamAccountName"

# Target group naming. {0} is replaced with the cleaned attribute value.
$GroupNameTemplate = "APP-GROUP-PREFIX-{0}-Users"

# OU where new groups are created.
$GroupPath = "OU=TARGET-OU,DC=example,DC=com"

# Description prefix applied to newly created groups.
$GroupDescriptionPrefix = "Attribute-based access group for value"

$GroupScope    = "Global"
$GroupCategory = "Security"

$CreateMissingGroups     = $true
$SkipBlankAttributeValues = $true

# Keep this set to $true for dry runs.
# Change to $false only when ready to make live AD changes.
$WhatIfPreference = $true

#endregion Configuration

Import-Module ActiveDirectory -ErrorAction Stop

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$CsvPath        = Join-Path -Path $ScriptRoot -ChildPath $CsvFileName
$PlanOutputPath = Join-Path -Path $ScriptRoot -ChildPath $PlanOutputFileName

if (-not (Test-Path -Path $CsvPath)) {
    throw "CSV path not found: $CsvPath"
}

$Rows = Import-Csv -Path $CsvPath

if (-not $Rows) {
    throw "CSV file is empty: $CsvPath"
}

$FirstRow = $Rows | Select-Object -First 1

if (-not ($FirstRow.PSObject.Properties.Name -contains $AttributeColumn)) {
    throw "CSV does not contain attribute column: $AttributeColumn"
}

if (-not ($FirstRow.PSObject.Properties.Name -contains $UserIdentityColumn)) {
    throw "CSV does not contain user identity column: $UserIdentityColumn"
}

# Build a plan of user-to-group mappings.
$Plan = foreach ($Row in $Rows) {
    $AttributeValue = $Row.$AttributeColumn
    $UserIdentity   = $Row.$UserIdentityColumn

    if ([string]::IsNullOrWhiteSpace($UserIdentity)) {
        Write-Warning "Row has blank value for '$UserIdentityColumn'. Skipping."
        continue
    }

    if ([string]::IsNullOrWhiteSpace($AttributeValue)) {
        if ($SkipBlankAttributeValues) {
            Write-Warning "User '$UserIdentity' has blank value for '$AttributeColumn'. Skipping."
            continue
        }
    }

    # Strip characters that are not valid for a group name segment.
    $CleanAttributeValue = ($AttributeValue -replace '[^a-zA-Z0-9_-]', '').Trim()

    if ([string]::IsNullOrWhiteSpace($CleanAttributeValue)) {
        Write-Warning "User '$UserIdentity' has invalid value '$AttributeValue' for '$AttributeColumn'. Skipping."
        continue
    }

    $TargetGroupName = $GroupNameTemplate -f $CleanAttributeValue

    [PSCustomObject]@{
        UserIdentity        = $UserIdentity
        AttributeColumn     = $AttributeColumn
        AttributeValue      = $AttributeValue
        CleanAttributeValue = $CleanAttributeValue
        TargetGroupName     = $TargetGroupName
    }
}

if (-not $Plan) {
    Write-Warning "No valid users found to process."
    return
}

$Plan |
    Sort-Object TargetGroupName, UserIdentity |
    Export-Csv -Path $PlanOutputPath -NoTypeInformation -Encoding UTF8

Write-Host "Membership plan exported to: $PlanOutputPath"
Write-Host ""

# Process one target group at a time.
$GroupedPlan = $Plan | Group-Object TargetGroupName

foreach ($Group in $GroupedPlan) {
    $TargetGroupName = $Group.Name
    $UsersForGroup   = $Group.Group

    Write-Host "Group: $TargetGroupName"
    Write-Host "Users to process: $($UsersForGroup.Count)"

    # Look up the group. A "not found" is treated as "does not exist".
    $ADGroup = $null
    try {
        $ADGroup = Get-ADGroup -Identity $TargetGroupName -ErrorAction Stop
    }
    catch {
        $ADGroup = $null
    }

    # Cache existing members so we do not re-add.
    $ExistingMemberLookup = @{}

    if ($ADGroup) {
        try {
            Get-ADGroupMember -Identity $TargetGroupName -ErrorAction Stop |
                ForEach-Object {
                    $ExistingMemberLookup[$_.DistinguishedName] = $true
                }
        }
        catch {
            Write-Warning "Could not read existing members for $TargetGroupName. Error: $($_.Exception.Message)"
        }
    }

    # Create the group if needed.
    if (-not $ADGroup) {
        if (-not $CreateMissingGroups) {
            Write-Warning "Group does not exist and group creation is disabled: $TargetGroupName"
            continue
        }

        $FirstAttributeValue = $UsersForGroup[0].AttributeValue
        $Description = "$GroupDescriptionPrefix $FirstAttributeValue"

        if ($PSCmdlet.ShouldProcess($TargetGroupName, "Create AD group")) {
            New-ADGroup `
                -Name $TargetGroupName `
                -SamAccountName $TargetGroupName `
                -GroupScope $GroupScope `
                -GroupCategory $GroupCategory `
                -Path $GroupPath `
                -Description $Description `
                -ErrorAction Stop

            $ADGroup = Get-ADGroup -Identity $TargetGroupName -ErrorAction Stop
        }
    }

    # Add each user to the group.
    foreach ($User in $UsersForGroup) {
        $UserIdentity = $User.UserIdentity

        $ADUser = Get-ADUser -Identity $UserIdentity -ErrorAction SilentlyContinue

        if (-not $ADUser) {
            Write-Warning "User not found in AD: $UserIdentity"
            continue
        }

        if ($ExistingMemberLookup.ContainsKey($ADUser.DistinguishedName)) {
            Write-Host "$UserIdentity is already a member of $TargetGroupName"
            continue
        }

        if ($PSCmdlet.ShouldProcess($UserIdentity, "Add to $TargetGroupName")) {
            try {
                Add-ADGroupMember `
                    -Identity $TargetGroupName `
                    -Members $ADUser.SamAccountName `
                    -ErrorAction Stop

                Write-Host "Added $UserIdentity to $TargetGroupName"
            }
            catch {
                if ($_.Exception.Message -match "already a member") {
                    Write-Host "$UserIdentity is already a member of $TargetGroupName"
                }
                else {
                    Write-Warning "Failed to add $UserIdentity to $TargetGroupName. Error: $($_.Exception.Message)"
                }
            }
        }
    }

    Write-Host ""
}
