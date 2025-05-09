
$TargetWindowTitle = "*Oblivion*" 
$NumberOfClicks    = 20


try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName Microsoft.VisualBasic 
} catch {
    Write-Error "Failed to load required .NET assemblies. Script cannot continue."
    exit 1
}

Write-Host "Searching for window with title like '$TargetWindowTitle'..."
$targetProcess = Get-Process | Where-Object { $_.MainWindowTitle -like $TargetWindowTitle -and $_.MainWindowHandle -ne [System.IntPtr]::Zero }

if ($null -eq $targetProcess) {
    Write-Error "Error: No running process found with a main window title like '$TargetWindowTitle'. Exiting."
    exit 1
} elseif ($targetProcess.Count -gt 1) {
    Write-Warning "Warning: Found multiple processes matching the title pattern. Selecting the first one found:"
    Write-Warning ("PID: {0}, Name: {1}, Title: {2}" -f $targetProcess[0].Id, $targetProcess[0].Name, $targetProcess[0].MainWindowTitle)
    $targetProcess = $targetProcess[0] 
} else {
    Write-Host ("Found target process: PID {0}, Name: {1}, Title: '{2}'" -f $targetProcess.Id, $targetProcess.Name, $targetProcess.MainWindowTitle)
}

$targetProcessId = $targetProcess.Id

Write-Host "--> Waiting for the initial delay of $InitialDelay seconds..."
Write-Host "(Target window activation will be attempted AFTER this delay)"
Write-Host "(Press CTRL+C in this PowerShell window to stop early)"

Write-Host "--> Initial delay finished. Attempting to activate target window (PID: $targetProcessId)..."

try {
    [Microsoft.VisualBasic.Interaction]::AppActivate($targetProcessId)
    Start-Sleep -Milliseconds 500 # Adjust if needed (250-1000ms is typical)
    Write-Host "Activation command sent. Now sending $NumberOfClicks rapid spacebar presses..."
    Write-Host "(Keys will go to whichever window is ACTUALLY active right now)"

} catch {
    Write-Warning "Warning: Could not activate process ID $targetProcessId. Sending keys to current foreground window instead."
}

$startTime = Get-Date

for ($i = 1; $i -le $NumberOfClicks; $i++) {
    [System.Windows.Forms.SendKeys]::SendWait(" ")
    Start-Sleep -Milliseconds 10
}

$endTime = Get-Date
Write-Progress -Activity "Sending Rapid Keystrokes" -Completed -Id 1
Write-Host "--> Script finished sending $NumberOfClicks rapid presses."
$timeTaken = $endTime - $startTime
Write-Host "Rapid press phase took $($timeTaken.TotalSeconds) seconds."