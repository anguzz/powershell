<#
.SYNOPSIS
Exports all user members of an AD group along with selected attributes.

.DESCRIPTION
Reads every user member of a source AD group and exports selected properties to a CSV.

The attribute used for downstream grouping (for example, a cost center attribute) is
configurable at the top of the script. Add more attributes to the export by editing
the $ExtensionAttributes array.

Output files are written to the same folder as this script.
#>

#region Configuration

# Source group to read members from.
$GroupName = "SOURCE-GROUP-NAME"

# Output file names (written next to this script).
$OutputFileName            = "GroupMembers.csv"
$UniqueValuesFileName      = "UniqueAttributeValues.csv"

# Attribute used to group users later (set to your cost center attribute).
$GroupingAttribute = "extensionAttributeX"

# Attributes to include in the export. Add more as needed.
$ExtensionAttributes = @(
    $GroupingAttribute
)

#endregion Configuration

Import-Module ActiveDirectory -ErrorAction Stop

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$OutputPath            = Join-Path -Path $ScriptRoot -ChildPath $OutputFileName
$UniqueValuesOutputPath = Join-Path -Path $ScriptRoot -ChildPath $UniqueValuesFileName

# Base properties plus any extension attributes to retrieve.
$UserProperties = @(
    "DisplayName",
    "GivenName",
    "Surname",
    "SamAccountName",
    "UserPrincipalName",
    "Mail",
    "Enabled"
) + $ExtensionAttributes

Write-Host "Getting members from group: $GroupName"

$Members = Get-ADGroupMember -Identity $GroupName -Recursive |
    Where-Object { $_.objectClass -eq "user" }

$Results = foreach ($Member in $Members) {

    $User = Get-ADUser -Identity $Member.SamAccountName -Properties $UserProperties

    $Obj = [ordered]@{
        DisplayName       = $User.DisplayName
        GivenName         = $User.GivenName
        Surname           = $User.Surname
        SamAccountName    = $User.SamAccountName
        UserPrincipalName = $User.UserPrincipalName
        Mail              = $User.Mail
        Enabled           = $User.Enabled
    }

    foreach ($Attribute in $ExtensionAttributes) {
        $Obj[$Attribute] = $User.$Attribute
    }

    [PSCustomObject]$Obj
}

$Results |
    Sort-Object DisplayName |
    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "Exported $($Results.Count) users to $OutputPath"

# Export the list of unique values for the grouping attribute.
$UniqueValues = $Results |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.$GroupingAttribute) } |
    ForEach-Object {
        [PSCustomObject]@{
            Value = $_.$GroupingAttribute
        }
    } |
    Sort-Object Value -Unique

$UniqueValues |
    Export-Csv -Path $UniqueValuesOutputPath -NoTypeInformation -Encoding UTF8

Write-Host "Exported $($UniqueValues.Count) unique '$GroupingAttribute' values to $UniqueValuesOutputPath"
