#requires -Modules ActiveDirectory
Import-Module ActiveDirectory -ErrorAction Stop

# Start transcript
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = ".\Add-ADGroupNesting_$timestamp.log"
Start-Transcript -Path $logFile

Write-Host "==== Script Started: $(Get-Date) ====" -ForegroundColor Cyan

$targetGroup = "Target-Group-Name" # Change to your target parent group name

$wildcard = "SG-PREFIX*"
# for example, app-users-01, app-users-02, app-users-03, etc you would use app-users*

Write-Host "Target group: $targetGroup"
Write-Host "Wildcard: $wildcard"

# Get groups
$groups = Get-ADGroup -Filter "Name -like '$wildcard'"

Write-Host "Total wildcard groups found: $($groups.Count)"

# Counter
$addedCount = 0

foreach ($group in $groups) {
    Write-Host "Processing: $($group.Name)"

    try {

         Add-ADGroupMember -Identity $targetGroup -Members $group # -WhatIf 
         # uncomment what if to test, comment out for live run
         
         $addedCount++
         Write-Host "Added: $($group.Name)" -ForegroundColor Green
    }
    catch {
        Write-Host "Skipped/Error: $($group.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Total groups added: $addedCount" -ForegroundColor Cyan
Write-Host "==== Script Completed: $(Get-Date) ====" -ForegroundColor Cyan

Stop-Transcript