Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Entra Admin MFA Registration Audit" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/4] Connecting to Microsoft Graph..." -ForegroundColor Yellow

Connect-MgGraph -Scopes `
    "Reports.Read.All", `
    "Directory.Read.All", `
    "RoleManagement.Read.Directory" `
    -NoWelcome

Write-Host "[2/4] Retrieving administrator registration data..." -ForegroundColor Yellow

$Admins = Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
    Where-Object { $_.IsAdmin -eq $true }

Write-Host "      Found $($Admins.Count) administrator account(s)." -ForegroundColor Green
Write-Host ""

Write-Host "[3/4] Looking for administrators not registered for MFA..." -ForegroundColor Yellow

$Results = foreach ($Admin in $Admins) {

    Write-Host "      Checking $($Admin.UserPrincipalName)..." -ForegroundColor Gray

    if (-not $Admin.IsMfaRegistered) {

        Write-Host "         MFA NOT REGISTERED" -ForegroundColor Red

        $Roles = @()

        try {
            $Assignments = Get-MgRoleManagementDirectoryRoleAssignment -All |
                Where-Object { $_.PrincipalId -eq $Admin.Id }

            foreach ($Assignment in $Assignments) {
                $Role = Get-MgRoleManagementDirectoryRoleDefinition `
                    -UnifiedRoleDefinitionId $Assignment.RoleDefinitionId

                $Roles += $Role.DisplayName
            }
        }
        catch {
            $Roles += "Unable to determine"
        }

        [PSCustomObject]@{
            DisplayName       = $Admin.UserDisplayName
            UserPrincipalName = $Admin.UserPrincipalName
            IsMfaRegistered   = $Admin.IsMfaRegistered
            IsMfaCapable      = $Admin.IsMfaCapable
            Roles             = ($Roles | Select-Object -Unique) -join ", "
        }
    }
}

Write-Host ""
Write-Host "[4/4] Audit Complete" -ForegroundColor Yellow
Write-Host ""

if ($Results) {

    Write-Host "======================================================" -ForegroundColor Red
    Write-Host " ADMINISTRATORS WITHOUT MFA REGISTRATION" -ForegroundColor Red
    Write-Host "======================================================" -ForegroundColor Red
    Write-Host ""

    $Results | Format-Table -AutoSize

}
else {

    Write-Host "======================================================" -ForegroundColor Green
    Write-Host " GOOD NEWS" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "All administrator accounts are registered for MFA." -ForegroundColor Green

}

Write-Host ""
Write-Host "Column Definitions:" -ForegroundColor Cyan
Write-Host "  IsMfaRegistered = User has registered at least one MFA method." -ForegroundColor Gray
Write-Host "  IsMfaCapable    = User can satisfy MFA requirements." -ForegroundColor Gray
Write-Host "  Roles           = Administrative roles assigned to the account." -ForegroundColor Gray
Write-Host ""
