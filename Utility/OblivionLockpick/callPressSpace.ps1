
$TargetScriptName = "pressSpace.ps1"
$IntervalSeconds = 1
$DurationMinutes = 1

$ScriptFolder = $PSScriptRoot
$TargetScriptPath = Join-Path -Path $ScriptFolder -ChildPath $TargetScriptName

if (-not (Test-Path -Path $TargetScriptPath -PathType Leaf)) {
    Write-Error "Error: Target script '$TargetScriptName' not found in folder '$ScriptFolder'."
    exit 1 
}


$EndTime = (Get-Date).AddMinutes($DurationMinutes)
$CallCount = 0

Write-Host "Starting simple caller for '$TargetScriptName'..."
Write-Host "Will run every $IntervalSeconds second(s) for $DurationMinutes minute(s)."
Write-Warning "Each call will attempt to run '$TargetScriptName' AS ADMINISTRATOR and will likely trigger a UAC prompt."
Write-Warning "The admin window will close automatically after the script finishes."

while ((Get-Date) -lt $EndTime) {
    $CallStartTime = Get-Date
    $CallCount++
    Write-Host "[$CallStartTime] Attempting to call '$TargetScriptName' as Admin (Call #$CallCount)..."

    try {
        Start-Process powershell.exe -ArgumentList "-File", """$TargetScriptPath""" -Verb RunAs -ErrorAction Stop
    } catch {
        Write-Error "Error executing '$TargetScriptName' as Admin: $($_.Exception.Message)"
    }

    $TimeElapsed = (Get-Date) - $CallStartTime
    $SleepMillis = [Math]::Max(0, ($IntervalSeconds * 1000) - $TimeElapsed.TotalMilliseconds)

    if ($SleepMillis -gt 0) {
        if ((Get-Date).AddMilliseconds($SleepMillis) -ge $EndTime) {
            break 
        }
        Start-Sleep -Milliseconds $SleepMillis
    }

    if ((Get-Date) -ge $EndTime) {
        break
    }
}

Write-Host "----------------------------------"
Write-Host "Finished. Attempted to call '$TargetScriptName' as Admin $CallCount times."
