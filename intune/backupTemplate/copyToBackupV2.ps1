
#------------------------------------------------------------------------------
# --- TEMPLATE CONFIGURATION - MODIFY VARIABLES BELOW ---
#------------------------------------------------------------------------------

# --- Source Directory ---
# The folder you want to back up.
$SourceDirectory = "C:\ProgramData\amagent\"

# --- Destination Settings ---
# The exact name of the user's OneDrive sync folder. Find this in C:\Users\<username>\
$OneDriveFolderName = "OneDrive - Foundation Building Materials"
# The relative path INSIDE the OneDrive folder where backups should be stored.
# Example: "Backups\AppLogs" will result in C:\Users\<user>\OneDrive...\Backups\AppLogs
$OneDriveRelativePath = "Documents\Log-Exports"
# A name for the specific backup job, used to create a parent folder for date-stamped backups.
# Example: "AppX_Backup" will result in ...\Log-Exports\AppX_Backup\AppName_MM-DD-YY
$BackupJobName = "amagent_backup"
# Prefix for the date-stamped folder name (e.g., "backup", "automox_log")
$DateFolderNamePrefix = "automox" # Results in "automox_MM-dd-yy"

# --- Backup Retention ---
# The number of recent backup folders (date-stamped) to keep. Older ones will be deleted.
$BackupsToKeep = 3

# --- Logging ---
# Fallback location if user's path cannot be determined early on.
$FallbackLogLocation = "C:\Windows\Temp"
# Base filename for the script's own operational log (will include timestamp).
$ScriptLogBaseName = "UserFolderBackup_ScriptLog"
# Base filename for the Robocopy output log (will be placed in backup destination).
$RobocopyLogBaseName = "robocopy_backup_log"

# --- Robocopy Options ---
# Retry count and wait time for failed file copies.
$RobocopyRetryCount = 3
$RobocopyWaitTimeSeconds = 5
# Robocopy flags for copying. /COPY:DATSO avoids auditing permission issues.
# D=Data, A=Attributes, T=Timestamps, S=Security(ACLs), O=Owner
$RobocopyCopyFlags = "/COPY:DATSO"
# Other common flags: /MIR (Mirror), /Z (Restartable), /NP (No Progress), /NJH (No Header), /NJS (No Summary)
$RobocopyOtherFlags = @(
    "/MIR",
    "/Z",
    "/NP",
    "/NJH",
    "/NJS"
)

#------------------------------------------------------------------------------
# --- END OF CONFIGURATION --- DO NOT MODIFY BELOW UNLESS NECESSARY ---
#------------------------------------------------------------------------------

# --- Initialize Script ---
$ErrorActionPreference = "Stop" # Make most script errors terminating
$StartTime = Get-Date
$FallbackLogFile = Join-Path -Path $FallbackLogLocation -ChildPath "$($ScriptLogBaseName)_$($StartTime.ToString('yyyyMMddHHmmss')).log"
$DestinationBase = $null # Will be determined dynamically
$RobocopyLogFile = $null # Will be set later

# --- Function to Log Messages ---
Function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $false)][string]$FilePath = $FallbackLogFile # Default to fallback until destination is known
    )
    # Always try to use the determined Robocopy log folder path if available later
    $EffectiveLogPath = $FilePath
    if ($null -ne $RobocopyLogFile) {
        $BackupLogFolder = Split-Path -Path $RobocopyLogFile -Parent
        $ScriptLogDestinationFile = Join-Path -Path $BackupLogFolder -ChildPath "$($ScriptLogBaseName)_CurrentRun.log"
        $EffectiveLogPath = $ScriptLogDestinationFile
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $EffectiveLogPath -Append -Encoding UTF8
    Write-Host "$timestamp - $Message" # Also output to console/Intune logs
}

# --- Main Script Logic ---
try {
    Write-Log -Message "Script started. Version 1.1"
    Write-Log -Message "Source Directory: $SourceDirectory"

    # --- Detect Logged-in User and Construct OneDrive Path ---
    $loggedInUsername = $null
    $userProfilePath = $null
    $explorerProcess = $null # Initialize to null

    try {
        Write-Log -Message "Attempting to detect logged-in user..."
        $loggedOnSession = Get-CimInstance Win32_LogonSession -Filter 'LogonType = 2' -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($null -ne $loggedOnSession) {
            $sessionId = $loggedOnSession.SessionId
            Write-Log -Message "Debug: Found interactive Logon SessionId: $sessionId"
            if ($null -ne $sessionId -and $sessionId -match '^\d+$') {
                $filter = "Name = 'explorer.exe' AND SessionId = $sessionId"
                Write-Log -Message "Debug: Attempting process filter: $filter"
                try {
                    $explorerProcess = Get-CimInstance Win32_Process -Filter $filter -ErrorAction Stop | Select-Object -First 1
                    if ($null -ne $explorerProcess) { Write-Log -Message "Debug: Found explorer process using SessionId filter." }
                    else { Write-Log -Message "Debug: No explorer process found matching SessionId filter '$filter'. Will attempt fallback." }
                } catch {
                    Write-Log -Message "Warning: Get-CimInstance failed with SessionId filter '$filter'. Error: $($_.Exception.Message). Will attempt fallback."
                    $explorerProcess = $null
                }
            } else {
                Write-Log -Message "Debug: Invalid or null SessionId ($sessionId) found for LogonType 2 session. Will attempt fallback."
                $explorerProcess = $null
            }
        } else {
             Write-Log -Message "Debug: No interactive logon session (Type 2) found. Will attempt fallback."
             $explorerProcess = $null
        }

        # Fallback: Find *any* explorer.exe if the SessionId method failed
        if ($null -eq $explorerProcess) {
            Write-Log -Message "Debug: Attempting fallback: Searching for any 'explorer.exe' process."
            try {
                $explorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction Stop | Select-Object -First 1
                if ($null -ne $explorerProcess) { Write-Log -Message "Debug: Found explorer process using fallback filter (no SessionId)." }
                else { Write-Log -Message "Debug: Fallback search also found no 'explorer.exe' process." }
            } catch {
                 Write-Log -Message "Warning: Get-CimInstance failed during fallback search for 'explorer.exe'. Error: $($_.Exception.Message)"
                 $explorerProcess = $null
            }
        }

        # Final Check and Owner Retrieval
        if ($null -eq $explorerProcess) {
            Throw "Could not find explorer.exe process for any active user using primary or fallback methods."
        }

        $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner
        if ($null -eq $ownerInfo -or [string]::IsNullOrEmpty($ownerInfo.User)) {
            Throw "Could not retrieve owner information for the found explorer.exe process."
        }

        $loggedInUsername = $ownerInfo.User
        $userDomain = $ownerInfo.Domain

        if ($loggedInUsername -like '*$' -or $loggedInUsername -eq 'SYSTEM' -or $loggedInUsername -eq 'LOCAL SERVICE' -or $loggedInUsername -eq 'NETWORK SERVICE') {
            Throw "Detected system account ($loggedInUsername) as owner of explorer.exe. Cannot target a user's OneDrive."
        }
        Write-Log -Message "Detected logged-in user: $userDomain\$loggedInUsername"

        # Construct Paths
        $userProfilePath = Join-Path -Path "C:\Users" -ChildPath $loggedInUsername
        $destinationBase = Join-Path -Path $userProfilePath -ChildPath $OneDriveFolderName | Join-Path -ChildPath $OneDriveRelativePath | Join-Path -ChildPath $BackupJobName

        # Verify/Create Base Destination Path
        if (!(Test-Path -Path $destinationBase -PathType Container)) {
             $oneDriveRoot = Join-Path -Path $userProfilePath -ChildPath $OneDriveFolderName
             if (!(Test-Path -Path $oneDriveRoot -PathType Container)) {
                 Throw "The OneDrive folder '$oneDriveRoot' does not exist or is not accessible for user '$loggedInUsername'."
             } else {
                 Write-Log -Message "Base destination path '$destinationBase' does not exist. Attempting to create."
                 try {
                     New-Item -Path $destinationBase -ItemType Directory -Force -ErrorAction Stop | Out-Null
                     Write-Log -Message "Successfully created destination base path '$destinationBase'."
                 } catch {
                     Throw "Failed to create destination base path '$destinationBase'. Error: $($_.Exception.Message)"
                 }
             }
        } else {
             Write-Log -Message "Verified destination base path: $destinationBase"
        }

    } catch {
        Write-Log -Message "CRITICAL ERROR during user detection or path setup: $($_.Exception.Message). Script cannot continue."
        Exit 1 # Exit script with an error code
    }

    # --- Prepare Backup Folders and Log File Path for this Run ---
    $backupDate = Get-Date -Format "MM-dd-yy"
    $backupFolderName = "$($DateFolderNamePrefix)_$backupDate" # e.g., automox_04-22-25
    $backupFolderFullPath = Join-Path -Path $destinationBase -ChildPath $backupFolderName # Specific folder for this run
    $logFolderFullPath = Join-Path -Path $backupFolderFullPath -ChildPath "BackupLogs" # Log folder *inside* the date-specific backup
    $RobocopyLogFile = Join-Path -Path $logFolderFullPath -ChildPath "$($RobocopyLogBaseName).txt" # Specific Robocopy log file path is now known

    # Create the specific backup and log directories if they don't exist
    try {
        if (!(Test-Path -Path $logFolderFullPath -PathType Container)) {
            New-Item -ItemType Directory -Path $logFolderFullPath -Force -ErrorAction Stop | Out-Null
            Write-Log -Message "Created log folder: $logFolderFullPath"
        }
    } catch {
        Write-Log -Message "ERROR creating log folder '$logFolderFullPath': $($_.Exception.Message). Robocopy logging may fail or use fallback."
        # Allow script to continue but Robocopy might log elsewhere or fail logging.
        # Consider changing $RobocopyLogFile back to a fallback location if needed.
    }

    # --- Perform Robocopy ---
    Write-Log -Message "Starting Robocopy from '$SourceDirectory' to '$backupFolderFullPath'"
    Write-Log -Message "Robocopy log file will be: $RobocopyLogFile"

    $RobocopyArgs = @(
        $SourceDirectory,
        $backupFolderFullPath,
        $RobocopyCopyFlags, # e.g., /COPY:DATSO
        "/R:$RobocopyRetryCount",
        "/W:$RobocopyWaitTimeSeconds",
        "/LOG+:$RobocopyLogFile" # Append to the log file
    ) + $RobocopyOtherFlags # Add flags like /MIR, /Z etc.

    Write-Log -Message "Robocopy arguments: $($RobocopyArgs -join ' ')"

    # Execute Robocopy
    robocopy @RobocopyArgs

    # Check Robocopy Exit Code (0-7 are success/minor issues, >=8 is failure)
    $exitCode = $LASTEXITCODE
    Write-Log -Message "Robocopy finished with exit code: $exitCode"
    if ($exitCode -ge 8) {
        Write-Log -Message "ERROR: Robocopy encountered a significant error (Exit code >= 8). Check log: $RobocopyLogFile"
        # Optional: Add specific error handling or notification here
    } elseif ($exitCode -gt 0) {
         Write-Log -Message "INFO: Robocopy completed with minor issues (Exit code $exitCode). Check log: $RobocopyLogFile"
    } else {
         Write-Log -Message "Robocopy completed successfully (Exit code 0)."
    }


    # --- Clean Up Old Backups ---
    Write-Log -Message "Cleaning up old backups in '$destinationBase', keeping the $BackupsToKeep most recent."
    try {
        $folders = Get-ChildItem -Path $destinationBase -Directory -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -match "^$([regex]::Escape($DateFolderNamePrefix))_\d{2}-\d{2}-\d{2}$" } | # Match naming pattern
                   Sort-Object CreationTime -Descending

        if ($null -ne $folders -and $folders.Count -gt $BackupsToKeep) {
            $foldersToDelete = $folders | Select-Object -Skip $BackupsToKeep
            Write-Log -Message "Found $($folders.Count) backup folders. Deleting $($foldersToDelete.Count) older ones:"
            foreach ($folder in $foldersToDelete) {
                Write-Log -Message "Deleting: $($folder.FullName)"
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Continue # Log error but continue cleanup
                if ($?) { Write-Log -Message "Successfully deleted $($folder.Name)." }
                else { Write-Log -Message "Warning: Failed to delete $($folder.FullName). Check permissions or locks."}
            }
        } else {
            $count = if ($null -eq $folders) { 0 } else { $folders.Count }
            Write-Log -Message "Found $count backup folders matching pattern. No cleanup needed (keeping up to $BackupsToKeep)."
        }
    } catch {
        Write-Log -Message "Warning: Error occurred during cleanup of old backups in '$destinationBase': $($_.Exception.Message)"
    }

    Write-Log -Message "Script finished successfully."

} catch {
    # Catch any unexpected script-level errors not handled elsewhere
    $errorMessage = "FATAL SCRIPT ERROR: $($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log -Message $errorMessage
    Exit 1 # Exit script with an error code
}

# Determine final exit code based on Robocopy result
if ($exitCode -ge 8) {
    Exit 1 # Robocopy failed significantly
} else {
    Exit 0 # Script completed (Robocopy success or minor issues)
}