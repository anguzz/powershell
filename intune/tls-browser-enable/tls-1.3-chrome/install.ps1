<#
Closes any running Chrome processes.
Iterates through all user profiles on the local device.
Specifically handles the current signed-in user.
Deletes the existing Local State file at %localappdata%\Google\Chrome\User Data\Local State from each user's Chrome profile.
Copies the pre-configured Local State file with TLS 1.3 toggled on from our files folder.

Disclaimer: Will sign users out of most applications and remove their cached login info, etc.
#>



$scriptPath = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$sourcePath = Join-Path $scriptPath "Files"
$localStateReplacementSource = Join-Path $sourcePath "Local State"
$logFile = "C:\LogFiles\TLSinstallLogChrome.txt"  # Central log file location

# check log directory exists
$logDir = "C:\LogFiles"
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory | Out-Null
}


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

# Attempt to close any running Chrome processes
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Log "Chrome processes have been stopped."

# this portion handles current user local statefile
$currentUserDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$currentLocalStatePath = "$currentUserDataPath\Local State"
if (Test-Path -Path $currentUserDataPath) {
    try {
        if (Test-Path -Path $currentLocalStatePath) {
            Remove-Item -Path $currentLocalStatePath -Force
        }aQQ    q   q   qaqq        q   
        Copy-Item -Path $localStateReplacementSource -Destination $currentLocalStatePath -Force
        Write-Log "TLS enabled for the current user ($env:USERNAME)"
    } catch {
        Write-Log "Failed TLS enablement for the current user ($env:USERNAME)"
    }
} else {
    Write-Log "Chrome User Data path does not exist for the current user: $currentUserDataPath"
}

# Loop through each user profile directory in the system
$userDataPaths = Get-ChildItem -Path C:\Users -Directory | ForEach-Object { $_.FullName + "\AppData\Local\Google\Chrome\User Data" }

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
        Write-Log "Chrome User Data path does not exist for: $path"
    }
}

Write-Log "Local State files have been replaced for all applicable profiles. Process completed."
