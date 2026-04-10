<#
Closes any running Edge processes.
Removes our local state file with flags enabled
Edge will generate a local state file with default flags

Disclaimer: Will sign users out of most applications/sessions
#>


# Define the path of the log file
$logFile = "C:\LogFiles\TLSinstallLogEdge.txt"

# Define the path to the Local State file in the Edge user data directory
$localStateFile = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"


try {
    Get-Process -name msedge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "All Edge processes have been stopped."
} catch {
    Write-Host "Failed to stop Edge processes or no Edge processes were running."
}

if (Test-Path -Path $logFile) {
    Remove-Item -Path $logFile -Force
    Write-Host "Log file deleted successfully."
} else {
    Write-Host "Log file not found."
}

if (Test-Path -Path $localStateFile) {
    Remove-Item -Path $localStateFile -Force
    Write-Host "Edge Local State file deleted successfully."
} else {
    Write-Host "Edge Local State file not found."
}
