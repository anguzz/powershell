#requires -Modules ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

$DomainDN = (Get-ADDomain).DistinguishedName

# Output
$OutputCsv = Join-Path -Path (Get-Location) -ChildPath "AD-Groups-Inventory.csv"

Write-Host "Fetching group inventory from AD..."

$groups = Get-ADGroup -Filter * -Properties `
    SamAccountName, Name, DistinguishedName, ObjectSID, ObjectGUID, `
    Description, info, ManagedBy, `
    whenCreated, whenChanged, `
    GroupCategory, GroupScope, `
    mail, member

$export = $groups | Where-Object {

    $dn = $_.DistinguishedName


    # Built-in AD container
    $dn -notmatch '^CN=.+,CN=Builtin,' -and

    # Common admin OU (optional but safe)
    $dn -notmatch '^CN=.+,OU=Admins,' -and

    # Default Users container (many built-in / system groups live here)
    $dn -notmatch ",CN=Users,$DomainDN$" -and

    # Exchange system groups (if Exchange exists)
    $dn -notmatch 'OU=Microsoft Exchange Security Groups' -and

    # ✅ Generic naming-based exclusions (infra/system groups)
    $_.SamAccountName -notmatch 'local-admins' -and
    $_.Name -notmatch 'local-admins' -and

    $_.Name -notmatch '^(Domain|Enterprise|Schema)\s' -and
    $_.Name -notmatch '^Exchange' -and
    $_.Name -notmatch '^RTC' -and
    $_.Name -notmatch '^RAS' -and
    $_.Name -notmatch 'RODC'

} | Select-Object `
    Name,
    SamAccountName,
    @{Name='GroupSamAccountName'; Expression={ $_.SamAccountName.ToLowerInvariant() }},
    DistinguishedName,
    @{Name='ObjectGUID'; Expression={ $_.ObjectGUID.ToString() }},
    @{Name='ObjectSID'; Expression={ $_.ObjectSID.Value }},
    GroupCategory,
    GroupScope,
    @{Name='IsMailEnabled'; Expression={ [bool]$_.mail }},
    @{Name='Description'; Expression={ $_.Description }},
    @{Name='Info'; Expression={ $_.info }},
    ManagedBy,
    whenCreated,
    whenChanged,
    @{Name='MemberCount'; Expression={ if ($_.member) { @($_.member).Count } else { 0 } }},
    @{Name='IsEmpty'; Expression={ -not $_.member }}

$export | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

Write-Host "Wrote: $OutputCsv"
Write-Host "Exported group count: $($export.Count)"