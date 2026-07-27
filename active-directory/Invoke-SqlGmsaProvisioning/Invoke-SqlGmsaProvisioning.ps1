<#
    New-SqlGmsaAccount.ps1

    Example script for creating SQL-related gMSAs and the
    associated password retrieval security groups.

    REVIEW BEFORE USE:
        - OU paths
        - Domain suffix
        - Naming standards
        - Delegated permissions

    Test in a non-production environment first.

    Usage:
        1) Edit the CONFIG section
        2) Run:

           .\New-SqlGmsaAccount.ps1

        3) On each target server:
           - Install the gMSA
           - Grant required rights
             * Log on as a service
             * Log on as a batch job
           - Reboot if required by your organization's process
#>

Import-Module ActiveDirectory

# ============================================================
# CONFIG
# ============================================================

# Environment Settings
$DomainFqdn       = "contoso.com"
$GroupOU          = "OU=Groups,DC=contoso,DC=com"
$ServiceAccountOU = "OU=ServiceAccounts,DC=contoso,DC=com"

# Naming Inputs
$ClusterName = "PRODSQL01"
$AppName     = "APP"
$Number      = "01"

# Target servers
$Nodes = @(
    "SERVER01"
    "SERVER02"
)

# Select required services
$Engine = $true
$Agent  = $false
$SSIS   = $false
$SSRS   = $false
$SSAS   = $false

# ============================================================
# DO NOT EDIT BELOW
# ============================================================

$AllServices = @(
    @{ Enabled = $Engine; Code = "et"; Name = "SQL Engine" }
    @{ Enabled = $Agent;  Code = "at"; Name = "SQL Agent"  }
    @{ Enabled = $SSIS;   Code = "it"; Name = "SSIS"       }
    @{ Enabled = $SSRS;   Code = "rt"; Name = "SSRS"       }
    @{ Enabled = $SSAS;   Code = "nt"; Name = "SSAS"       }
)

$Selected = $AllServices | Where-Object { $_.Enabled }

if (-not $Selected) {
    Write-Warning "No services selected."
    return
}

$app = $AppName.ToLower()

$Plan = foreach ($svc in $Selected) {

    $sam = "sq$($svc.Code)p$app$Number"

    [pscustomobject]@{
        Service    = $svc.Name
        GroupName  = "gMSA $sam"
        SamAccount = $sam
        Sam        = "$sam`$"
    }
}

Write-Host ""
Write-Host "Accounts to be created:" -ForegroundColor Cyan

$Plan | Format-Table Service,GroupName,Sam -AutoSize

Write-Host ""
Write-Host "Target servers:" -ForegroundColor Cyan

$Nodes | ForEach-Object {
    Write-Host "  $_"
}

$confirm = Read-Host "`nContinue? (Y/N)"

if ($confirm -notmatch '^(y|yes)$') {
    Write-Host "Cancelled."
    return
}

$Members = $Nodes | ForEach-Object { "$_`$" }

foreach ($item in $Plan) {

    Write-Host ""
    Write-Host "Processing $($item.Service)..." -ForegroundColor Cyan

    New-ADGroup `
        -Name $item.GroupName `
        -Description "Password retrieval group for $($item.Sam)" `
        -Path $GroupOU `
        -GroupScope Global `
        -GroupCategory Security

    Write-Output "Created AD Group: $($item.GroupName)"

    New-ADServiceAccount `
        -Name "gMSA $ClusterName $($item.Service)" `
        -sAMAccountName $item.SamAccount `
        -DNSHostName "$($item.SamAccount).$DomainFqdn" `
        -PrincipalsAllowedToRetrieveManagedPassword $item.GroupName `
        -Description "$ClusterName $($item.Service) gMSA" `
        -Path $ServiceAccountOU `
        -ManagedPasswordIntervalInDays 30

    Write-Output "Created gMSA: $($item.Sam)"

    try {
        Add-ADGroupMember `
            -Identity $item.GroupName `
            -Members $Members `
            -ErrorAction Stop

        Write-Output "Added members: $($Members -join ', ')"
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}

Write-Host ""
Write-Host "Completed successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Post-deployment tasks:" -ForegroundColor Yellow
Write-Host "  - Install-ADServiceAccount on target servers"
Write-Host "  - Grant service rights per organizational standards"
Write-Host "  - Validate account retrieval and service startup"