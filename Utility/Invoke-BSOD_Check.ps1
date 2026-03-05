$startDate = (Get-Date).AddDays(-30)
$endDate = Get-Date

# --- Focus specifically on the Bugcheck Event ID ---
$bsodEventID = 1001

$eventDescriptions = @{
    1001 = "Bugcheck (Blue Screen of Death / System Crash)."
}

# --- Get only the BSOD events from the System log ---
Write-Host "Searching for BSOD events (Event ID $bsodEventID) from $startDate to $endDate..."
$bsodEvents = Get-WinEvent -FilterHashtable @{
    LogName   = 'System' # BSOD Bugcheck events (1001) are in the System log
    ID        = $bsodEventID
    StartTime = $startDate
    EndTime   = $endDate
} -ErrorAction SilentlyContinue

if ($bsodEvents) {
    Write-Output "-----------------------------------------------------------------------------------------------------"
    Write-Output "`n                 Blue Screen of Death (Bugcheck) Report from $startDate to $endDate"
    Write-Output "`n`n"

    $count = 1
    foreach ($event in $bsodEvents) {
        $eventXml = [xml]$event.ToXml()

        $eventData = $eventXml.Event.EventData.Data
        $bugcheckCode = ($eventData | Where-Object { $_.Name -eq 'BugcheckCode' }).'#text'
        $param1 = ($eventData | Where-Object { $_.Name -eq 'BugcheckParameter1' }).'#text'
        $param2 = ($eventData | Where-Object { $_.Name -eq 'BugcheckParameter2' }).'#text'
        $param3 = ($eventData | Where-Object { $_.Name -eq 'BugcheckParameter3' }).'#text'
        $param4 = ($eventData | Where-Object { $_.Name -eq 'BugcheckParameter4' }).'#text'

        $bugcheckCodeHex = "0x{0:X}" -f [int]$bugcheckCode
        $details = "Bugcheck Code: $bugcheckCode ($bugcheckCodeHex), Parameters: $param1, $param2, $param3, $param4"

        Write-Output "BSOD Event $count"
        Write-Output "Time: $($event.TimeCreated)"
        Write-Output "Event ID: $($event.Id) - $($eventDescriptions[$event.Id])"
        Write-Output "Log Name: $($event.LogName)"
        Write-Output "Source: $($event.ProviderName)" 
        Write-Output "Bugcheck Details: $details"
        Write-Output "-------------------------------------------`n`n"
        $count++
    }
} else {
    Write-Output "No Blue Screen of Death events (Event ID $bsodEventID) found in the System log for the specified timeframe."
}

Write-Output "-----------------------------------------------------------------------------------------------------"

