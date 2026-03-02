
param(
    [int]$DaysToCheck = 30
)

$StartDate = (Get-Date).AddDays(-$DaysToCheck)

Write-Host "Checking System Event Log for Resource Exhaustion events (ID 2004) since $($StartDate.ToString('yyyy-MM-dd'))..." -ForegroundColor Cyan

try {
    $LowMemoryEvents = Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        ProviderName = 'Microsoft-Windows-Resource-Exhaustion-Detector' 
        ID        = 2004
        StartTime = $StartDate
    } -ErrorAction SilentlyContinue

    if ($LowMemoryEvents) {
        Write-Host "Found $($LowMemoryEvents.Count) low virtual memory event(s):" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------"
        $LowMemoryEvents | Select-Object TimeCreated, Message | Format-List
        Write-Host "--------------------------------------------------"
        Write-Host "Review the 'Message' field in the events above to see which programs were listed as consuming high memory." -ForegroundColor Green
    } else {
        Write-Host "No Event ID 2004 from Resource-Exhaustion-Detector found in the last $DaysToCheck days." -ForegroundColor Green
    }
}
catch {
    Write-Error "An error occurred querying the event log: $($_.Exception.Message)"
}

Write-Host "Event log check complete."