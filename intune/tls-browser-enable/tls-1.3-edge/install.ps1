<#
Closes any running Edge processes.
Iterates through all user profiles on the local device.
Deletes the existing Local State file at %localappdata%\Microsoft\Edge\User Data\Local State from each user's Edge profile.
Copies the pre-configured Local State file with TLS 1.3 toggled on from our files folder.

Disclaimer: May sign users out of certain applications and remove their cached login info, etc.
#>

# Define paths
$scriptPath = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$sourcePath = Join-Path $scriptPath "Files"
$localStateReplacementSource = Join-Path $sourcePath "Local State"
$logFile = "C:\LogFiles\TLSinstallLogEdge.txt"  # Central log file location

# Ensure the log directory exists
$logDir = "C:\LogFiles"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}

# Log function to write both to console and to a log file
function Write-Log {
    Param ([string]$logMessage)
    Write-Output $logMessage | Out-File -FilePath $logFile -Append
    Write-Host $logMessage
}

# Initialize log file
if (-not (Test-Path $logFile)) {
    New-Item -Path $logFile -ItemType File | Out-Null
}
Write-Log "Starting TLS 1.3 Local State replacement process."

# Check if the Local State replacement source file exists
if (!(Test-Path $localStateReplacementSource)) {
    Write-Log "Local State file not found at $localStateReplacementSource. Exiting."
    Exit 1
}

# Attempt to close any running Edge processes
Get-Process -name msedge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Log "Edge processes have been stopped."

# Loop through each user profile directory in the system
$userDataPaths = Get-ChildItem -Path C:\Users -Directory | ForEach-Object { $_.FullName + "\AppData\Local\Microsoft\Edge\User Data" }

foreach ($path in $userDataPaths) {
    $localStatePath = "$path\Local State"
    $username = Split-Path $path -Leaf
    
    # Ensure the path exists before attempting to delete or copy
    if (Test-Path -Path $path) {
        try {
            # Check if the Local State file exists, and delete it if it does
            if (Test-Path -Path $localStatePath) {
                Remove-Item -Path $localStatePath -Force
            }
            
            # Copy the pre-configured Local State file to the current user's profile
            Copy-Item -Path $localStateReplacementSource -Destination $localStatePath -Force
            Write-Log "TLS enabled for $username"
        } catch {
            Write-Log "Failed TLS enablement for $username"
        }
    } else {
        Write-Log "Edge User Data path does not exist for: $path"
    }
}

Write-Log "Local State files have been replaced for all applicable profiles. Process completed."
