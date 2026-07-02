[CmdletBinding()]
param (
    [string]$CsvPath = ".\Groups.csv",
    [string]$ServicePrincipalName = "",
    [string]$LogPath = ".\OwnerUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv",
    [switch]$WhatIf
)

Connect-MgGraph -Scopes Group.ReadWrite.All,Application.Read.All,RoleManagement.ReadWrite.Directory -UseDeviceCode -NoWelcome

Write-Host "Looking up Service Principal: $ServicePrincipalName" -ForegroundColor Cyan

$SP = Get-MgServicePrincipal -Filter "displayName eq '$ServicePrincipalName'"

if (-not $SP) {
    throw "Service Principal '$ServicePrincipalName' not found."
}

Write-Host "Found SP ObjectId: $($SP.Id)" -ForegroundColor Green

$Groups  = Import-Csv $CsvPath
$Results = @()

foreach ($Row in $Groups) {

    $GroupName = $Row.GroupName.Trim()

    Write-Host "`nProcessing: $GroupName" -ForegroundColor Cyan

    $Group = Get-MgGroup -Filter "displayName eq '$GroupName'"

    if (-not $Group) {
        Write-Warning "$GroupName not found"
        $Results += [PSCustomObject]@{
            GroupName = $GroupName
            GroupId   = $null
            Status    = "NotFound"
            Message   = "Group not found in directory"
        }
        continue
    }

    $Owners = Get-MgGroupOwner -GroupId $Group.Id -All

    if ($Owners.Id -contains $SP.Id) {
        Write-Host "Owner already assigned." -ForegroundColor Yellow
        $Results += [PSCustomObject]@{
            GroupName = $Group.DisplayName
            GroupId   = $Group.Id
            Status    = "AlreadyAssigned"
            Message   = "Service principal already an owner"
        }
        continue
    }

    if ($WhatIf) {

        Write-Host "[WHATIF] Would add service principal owner to '$GroupName'" -ForegroundColor Magenta
        $Results += [PSCustomObject]@{
            GroupName = $Group.DisplayName
            GroupId   = $Group.Id
            Status    = "WhatIf"
            Message   = "Would add owner"
        }

    }
    else {

        try {

            New-MgGroupOwnerByRef `
                -GroupId $Group.Id `
                -BodyParameter @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($SP.Id)"
                } -ErrorAction Stop

            Write-Host "Owner added successfully." -ForegroundColor Green
            $Results += [PSCustomObject]@{
                GroupName = $Group.DisplayName
                GroupId   = $Group.Id
                Status    = "Added"
                Message   = "Owner added"
            }

        }
        catch {

            Write-Error "Failed to add owner to '$GroupName'. $_"
            $Results += [PSCustomObject]@{
                GroupName = $Group.DisplayName
                GroupId   = $Group.Id
                Status    = "Failed"
                Message   = $_.Exception.Message
            }

        }
    }
}

$Results | Export-Csv -Path $LogPath -NoTypeInformation
Write-Host "`nResults exported to: $LogPath" -ForegroundColor Cyan