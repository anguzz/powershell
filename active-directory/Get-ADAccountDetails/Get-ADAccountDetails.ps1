#requires -Modules ActiveDirectory

[CmdletBinding()]
param(
[Parameter(Mandatory)]
[string]$InputCsv,

[Parameter(Mandatory)]
[string]$OutputCsv
)


Import-Module ActiveDirectory -ErrorAction Stop

Write-Output "Importing CSV..."
$rows = Import-Csv -Path $InputCsv

# Add/remove fields here as needed
$searchFields = @(
'Description'
'PasswordLastSet'
'MemberOf'
'Mail'
'msExchRecipientTypeDetails'
'WhenCreated'
'CanonicalName'
'Department'
)

Write-Output "Fetching AD results..."

$results = foreach ($row in $rows) {

    $raw = [string]$row.Account

    # Parse DOMAIN\samAccountName → samAccountName
    $sam = if ($raw -match '^[^\\]+\\(.+)$') { $Matches[1] } else { $raw }

    $found = $true
    $dn    = $null
    $adObj = $null

    try {
        try {
            $adObj = Get-ADUser -Identity $sam -Properties $searchFields -ErrorAction Stop
        } catch {
            try {
                $adObj = Get-ADComputer -Identity $sam -Properties Description,WhenCreated -ErrorAction Stop
            } catch {
                $adObj = Get-ADObject -LDAPFilter "(sAMAccountName=$sam)" -Properties Description,WhenCreated -ErrorAction Stop
            }
        }
    }
    catch {
        $found = $false
    }

    if ($found -and $adObj) {
        $dn = $adObj.DistinguishedName
    }

    [pscustomobject]@{
        Account                     = $raw
        SamAccountName              = $sam
        Found                       = $found
        DistinguishedName           = $dn

        Description                 = $adObj.Description
        Department                  = $adObj.Department
        Manager                     = $adObj.Manager
        Mail                        = $adObj.Mail
        CanonicalName               = $adObj.CanonicalName

        PasswordLastSet             = $adObj.PasswordLastSet
        CreatedDate                 = $adObj.WhenCreated

        MemberOf                    = ($adObj.MemberOf -join '; ')
        msExchRecipientTypeDetails  = $adObj.msExchRecipientTypeDetails
    }
}

$results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
Write-Host "Wrote: $OutputCsv"