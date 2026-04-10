<#
Closes any running Chrome processes.
Removes our local state file with flags enabled
Chrome will generate a local state file with default flags

Disclaimer: Will sign users out of most applications/sessions
#>


# Define the path of the log file
$logFile = "C:\LogFiles\TLSinstallLogChrome.txt"

# Define the path to the Local State file in the Chrome user data directory
$localStateFile = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"


try {
    Get-Process "chrome" -ErrorAction Stop | Stop-Process -Force
    Write-Host "All Chrome processes have been stopped."
} catch {
    Write-Host "Failed to stop Chrome processes or no Chrome processes were running."
}

if (Test-Path -Path $logFile) {
    Remove-Item -Path $logFile -Force
    Write-Host "Log file deleted successfully."
} else {
    Write-Host "Log file not found."
}

if (Test-Path -Path $localStateFile) {
    Remove-Item -Path $localStateFile -Force
    Write-Host "Chrome Local State file deleted successfully."
} else {
    Write-Host "Chrome Local State file not found."
}
