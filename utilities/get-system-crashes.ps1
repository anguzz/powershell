$startDate = (Get-Date).AddDays(-30)
$endDate = Get-Date

$eventIDs = 1000, 1001, 1005, 1026, 6008, 41 

$eventDescriptions = @{
    1000 = "Application error."
    1001 = "Bugcheck (system crash)."
    1005 = "Windows cannot access the file."
    1026 = ".NET Runtime error."
    6008 = "Unexpected shutdown."
    41 = "Kernel power event (system did not shut down cleanly)."
}

$crashEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'System' #, 'Application' # uncomment to add app crashes
    ID = $eventIDs
    StartTime = $startDate
    EndTime = $endDate
} -ErrorAction SilentlyContinue

if ($crashEvents) {
    Write-Output "-----------------------------------------------------------------------------------------------------"

    Write-Output "`n                   Expanded System Crash Report from $startDate to $endDate"
    Write-Output "`n`n"

    $count = 1
    foreach ($event in $crashEvents) {
        $eventXml = [xml]$event.ToXml()
        $details = $eventXml.Event.EventData.Data

        Write-Output "Crash Event $count"
        Write-Output "Time: $($event.TimeCreated)"
        Write-Output "Event ID: $($event.Id) - $($eventDescriptions[$event.Id])"
        Write-Output "Log Name: $($event.LogName)"
        Write-Output "Source: $($event.ProviderName)"
        Write-Output "Crash Details: $($details.'#text')"
        Write-Output "-------------------------------------------`n`n"
        $count++
    }
} else {
    Write-Output "No crash events found in the specified timeframe."
}
