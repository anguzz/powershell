<#
.SYNOPSIS
    Troubleshoots stuck group-assigned license removals for a user (typically a terminated user).

.DESCRIPTION
    Investigates why the built-in Lifecycle Workflow "Remove all licenses for user" task
    fails with a generic "inherited from group membership" error.

    Walks through:
      1. User license state (direct vs group-assigned, ActiveWithError / DependencyViolation)
      2. Group details for any assignedByGroup references (type, dynamic rule, sync source)
      3. Current group membership (direct + transitive)
      4. Lifecycle Workflow task processing results (if a workflow ID is provided)
      5. Optional forced license reprocess with real error surfaced

.PARAMETER UserId
    UPN or object ID of the user to investigate.

.PARAMETER WorkflowId
    Optional. Lifecycle Workflow ID to pull the failed task processing results for the user.

.PARAMETER Reprocess
    Optional switch. Forces reprocessLicenseAssignment on the user to surface the real
    reconciliation error. Requires User.ReadWrite.All + a role like User Administrator,
    License Administrator, or Global Administrator on the signed-in principal.

.EXAMPLE
    .\Debug-GroupLicenseAssignment.ps1 -UserId "user@contoso.com"

.EXAMPLE
    .\Debug-GroupLicenseAssignment.ps1 -UserId "user@contoso.com" -WorkflowId "<guid>" -Reprocess

.NOTES
    Read-only by default. Only performs a state change if -Reprocess is passed.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$UserId,

    [string]$WorkflowId,

    [switch]$Reprocess
)

# ------------------------------------------------------------
# Connect to Graph
# ------------------------------------------------------------
$scopes = @(
    "User.Read.All",
    "Group.Read.All",
    "Directory.Read.All",
    "LifecycleWorkflows.Read.All"
)

if ($Reprocess) {
    $scopes += "User.ReadWrite.All"
}

Write-Host "`n=== Connecting to Microsoft Graph ===" -ForegroundColor Cyan
Connect-MgGraph -Scopes $scopes -NoWelcome | Out-Null

# ------------------------------------------------------------
# 1. Get user + license state
# ------------------------------------------------------------
Write-Host "`n=== 1. User + License Assignment States ===" -ForegroundColor Cyan

$userSelect = "id,displayName,userPrincipalName,accountEnabled,employeeId,onPremisesExtensionAttributes,onPremisesLastSyncDateTime,licenseAssignmentStates,assignedLicenses"
$user = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$UserId`?`$select=$userSelect"

"User          : $($user.displayName) ($($user.userPrincipalName))"
"Object ID     : $($user.id)"
"Enabled       : $($user.accountEnabled)"
"Employee ID   : $($user.employeeId)"
"Last Synced   : $($user.onPremisesLastSyncDateTime)"
"extAttr2      : $($user.onPremisesExtensionAttributes.extensionAttribute2)"

Write-Host "`n--- License Assignment States ---"
$states = foreach ($state in $user.licenseAssignmentStates) {
    [PSCustomObject]@{
        SkuId           = $state.skuId
        State           = $state.state
        Error           = $state.error
        AssignedByGroup = $state.assignedByGroup
        LastUpdated     = $state.lastUpdatedDateTime
    }
}
$states | Format-Table -AutoSize

$erroredStates = $states | Where-Object { $_.State -eq "ActiveWithError" -or ($_.Error -and $_.Error -ne "None") }
if ($erroredStates) {
    Write-Host "!! Errored license states detected:" -ForegroundColor Yellow
    $erroredStates | Format-List
}

# ------------------------------------------------------------
# 2. Inspect each referenced group
# ------------------------------------------------------------
Write-Host "`n=== 2. Group Details for assignedByGroup References ===" -ForegroundColor Cyan

$groupIds = $states | Where-Object { $_.AssignedByGroup } | Select-Object -ExpandProperty AssignedByGroup -Unique

if (-not $groupIds) {
    Write-Host "No group-assigned licenses found on this user."
}
else {
    foreach ($gid in $groupIds) {
        Write-Host "`n--- Group: $gid ---" -ForegroundColor Green
        $groupSelect = "id,displayName,groupTypes,securityEnabled,mailEnabled,onPremisesSyncEnabled,membershipRule,membershipRuleProcessingState,assignedLicenses,licenseProcessingState"
        try {
            $group = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$gid`?`$select=$groupSelect"

            "DisplayName             : $($group.displayName)"
            "GroupTypes              : $($group.groupTypes -join ',')"
            "SecurityEnabled         : $($group.securityEnabled)"
            "MailEnabled             : $($group.mailEnabled)"
            "OnPremSyncEnabled       : $($group.onPremisesSyncEnabled)"
            "MembershipRuleState     : $($group.membershipRuleProcessingState)"
            "LicenseProcessingState  : $($group.licenseProcessingState.state)"
            if ($group.membershipRule) {
                "MembershipRule (masked) : [dynamic rule present - not printed]"
            }

            # Check if user is still a member (direct or transitive)
            Write-Host "`nMembership check for $($user.displayName):"

            $memberUri = "https://graph.microsoft.com/v1.0/groups/$gid/members?`$filter=id eq '$($user.id)'&`$count=true"
            $memberCheck = Invoke-MgGraphRequest -Method GET -Uri $memberUri -Headers @{ ConsistencyLevel = "eventual" }
            $isDirectMember = ($memberCheck.value.Count -gt 0)
            "Direct Member    : $isDirectMember"

            $transUri = "https://graph.microsoft.com/v1.0/users/$($user.id)/transitiveMemberOf/microsoft.graph.group?`$select=id,displayName&`$count=true"
            $transitive = Invoke-MgGraphRequest -Method GET -Uri $transUri -Headers @{ ConsistencyLevel = "eventual" }
            $isTransitiveMember = (($transitive.value | Where-Object { $_.id -eq $gid }).Count -gt 0)
            "Transitive Member: $isTransitiveMember"

            if (-not $isDirectMember -and -not $isTransitiveMember) {
                Write-Host "!! User is NOT in this group anymore, but license still references it. Stuck reference." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Warning "Could not fetch group ${gid}: $($_.Exception.Message)"
        }
    }
}

# ------------------------------------------------------------
# 3. Lifecycle Workflow task results (optional)
# ------------------------------------------------------------
if ($WorkflowId) {
    Write-Host "`n=== 3. Lifecycle Workflow Task Results ===" -ForegroundColor Cyan

    try {
        $uprUri = "https://graph.microsoft.com/beta/identityGovernance/lifecycleWorkflows/workflows/$WorkflowId/userProcessingResults?`$filter=subject/id eq '$($user.id)'"
        $upr = Invoke-MgGraphRequest -Method GET -Uri $uprUri

        if (-not $upr.value) {
            Write-Host "No userProcessingResults found for this user in workflow $WorkflowId."
        }
        else {
            foreach ($result in $upr.value) {
                "Run ID           : $($result.id)"
                "Processing Status: $($result.processingStatus)"
                "Failed Tasks     : $($result.failedTasksCount) / $($result.totalTasksCount)"
                "Completed        : $($result.completedDateTime)"

                $taskUri = "https://graph.microsoft.com/beta/identityGovernance/lifecycleWorkflows/workflows/$WorkflowId/userProcessingResults/$($result.id)/taskProcessingResults?`$filter=processingStatus eq 'failed'"
                $tasks = Invoke-MgGraphRequest -Method GET -Uri $taskUri

                if ($tasks.value) {
                    Write-Host "`n--- Failed Tasks ---" -ForegroundColor Yellow
                    foreach ($t in $tasks.value) {
                        [PSCustomObject]@{
                            Task          = $t.task.displayName
                            Category      = $t.task.category
                            Sequence      = $t.task.executionSequence
                            Status        = $t.processingStatus
                            FailureReason = $t.failureReason
                            Completed     = $t.completedDateTime
                        } | Format-List
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Could not fetch workflow results: $($_.Exception.Message)"
    }
}

# ------------------------------------------------------------
# 4. Force reprocess (optional - surfaces the real error)
# ------------------------------------------------------------
if ($Reprocess) {
    Write-Host "`n=== 4. Forcing reprocessLicenseAssignment ===" -ForegroundColor Cyan
    Write-Host "This is where the REAL reconciliation error surfaces (not the generic workflow message)." -ForegroundColor DarkGray

    try {
        $null = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)/reprocessLicenseAssignment"

        Write-Host "Reprocess call accepted. Waiting 5 seconds then re-checking license state..." -ForegroundColor Green
        Start-Sleep -Seconds 5

        $userAfter = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)?`$select=licenseAssignmentStates"

        Write-Host "`n--- License State After Reprocess ---"

        $userAfter.licenseAssignmentStates |
            Select-Object `
                @{N='SkuId';           E={$_.skuId}},
                @{N='State';           E={$_.state}},
                @{N='Error';           E={$_.error}},
                @{N='AssignedByGroup'; E={$_.assignedByGroup}},
                @{N='LastUpdated';     E={$_.lastUpdatedDateTime}} |
            Format-Table -AutoSize
    }
    catch {
        $err = $_.ErrorDetails.Message

        if ($err) {
            Write-Host "!! Reprocess returned an error (this is often the real root cause):" -ForegroundColor Red
            $err
        }
        else {
            Write-Warning "Reprocess failed: $($_.Exception.Message)"
        }
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host "Tip: If you saw a DependencyViolation on reprocess, check overlapping SKUs (base + add-ons like Visio/Project)"
Write-Host "     for conflicting 'disabledPlans' configuration."