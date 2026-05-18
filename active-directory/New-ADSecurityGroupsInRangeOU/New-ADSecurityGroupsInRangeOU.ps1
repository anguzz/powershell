<#
.SYNOPSIS
Bulk create AD Security Groups in a specific OU with a numeric suffix, using a start and end number range.

.EXAMPLE
# Create 55-60 
.\New-ADSecurityGroupsInRangeOU.ps1 -Prefix "Test SG " -StartNumber 55 -EndNumber 60 -OuDn "OU=Other,OU=MyGroups,OU=GROUPS,OU=OPUS,DC=EXAMPLE,DC=ORG" -PadWidth 2 -Verbose
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false)]
    [string]$Prefix = "Test SG ",

    [Parameter(Mandatory = $true)]
    [int]$StartNumber,

    [Parameter(Mandatory = $true)]
    [int]$EndNumber,

    [Parameter(Mandatory = $true)]
    [string]$OuDn,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 10)]
    [int]$PadWidth = 0,

    [Parameter(Mandatory=$false)]
    [string]$DescriptionTemplate = "Created in AD",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Universal","Global","DomainLocal")]
    [string]$GroupScope = "Global",

    [Parameter(Mandatory = $false)]
    [switch]$SkipIfExists
)

begin {
    # Requires RSAT ActiveDirectory module (or on a DC)
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw "ActiveDirectory module not found. Install RSAT AD tools or run on a domain-joined machine with RSAT."
    }
    Import-Module ActiveDirectory -ErrorAction Stop

    # Validate OU exists
    try {
        $null = Get-ADOrganizationalUnit -Identity $OuDn -ErrorAction Stop
    } catch {
        throw "OU not found or not accessible: $OuDn"
    }

    if ($EndNumber -lt $StartNumber) {
        throw "EndNumber [$EndNumber] must be greater than or equal to StartNumber [$StartNumber]."
    }

    Write-Verbose "Prefix     : [$Prefix]"
    Write-Verbose "StartNumber: $StartNumber"
    Write-Verbose "EndNumber  : $EndNumber"
    Write-Verbose "OU DN      : $OuDn"
    Write-Verbose "PadWidth   : $PadWidth"
    Write-Verbose "Scope      : $GroupScope"
}

process {

    for ($i = $StartNumber; $i -le $EndNumber; $i++) {

        $suffix = if ($PadWidth -gt 0) { $i.ToString("D$PadWidth") } else { $i.ToString() }
        $groupName = "$Prefix$suffix"

        # Check existence by Name
        $existing = Get-ADGroup -Filter "Name -eq '$groupName'" -ErrorAction SilentlyContinue

        if ($existing) {
            $msg = "Exists: $groupName (DN: $($existing.DistinguishedName))"
            if ($SkipIfExists) {
                Write-Verbose $msg
                continue
            } else {
                Write-Warning $msg
                continue
            }
        }

        # sAMAccountName max length is 20 chars
        $rawSam = ($groupName -replace '\s','')  # remove spaces
        if ($rawSam.Length -gt 20) {
            # Keep uniqueness at the end with the numeric suffix
            $maxBase = [Math]::Max(0, 20 - $suffix.Length)
            $base = $rawSam.Substring(0, [Math]::Min($maxBase, $rawSam.Length))
            $rawSam = ($base + $suffix)
            if ($rawSam.Length -gt 20) {
                $rawSam = $rawSam.Substring(0, 20)
            }
        }
        $samAccountName = $rawSam
        $description = [string]::Format($DescriptionTemplate, $suffix)
        $createMsg = "Create group [$groupName] in [$OuDn] with sAMAccountName [$samAccountName] scope [$GroupScope]"
        if ($PSCmdlet.ShouldProcess($groupName, $createMsg)) {
            try {
                New-ADGroup `
                    -Name $groupName `
                    -SamAccountName $samAccountName `
                    -GroupCategory Security `
                    -GroupScope $GroupScope `
                    -Path $OuDn `
                    -Description $description `
                    -ErrorAction Stop

                Write-Host "Created: $groupName"
            } catch {
                Write-Error "Failed to create [$groupName]. Error: $($_.Exception.Message)"
            }
        }
    }
}
