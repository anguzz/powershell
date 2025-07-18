
# The exact name of the user's OneDrive sync folder. Find this in C:\Users\<username>\
$oneDriveRootFolderName = "OneDrive - My Organization"

$oneDriveBackupSubfolder = "Documents\ChromeBookmark_backups"

$backupJobFolderName = "chrome_bookmark_backup"

$backupDatePrefix = "chrome_bookmark" # Results in "chrome_bookmark_07-18-25"

# --- Backup Retention ---
# The number of recent backup folders (date-stamped) to keep. Older ones will be deleted.
$maxBackupRetentionCount = 3

# --- Logging ---
# The full path for the script's operational log file.
$scriptLogFilePath = "C:\Windows\Temp\ChromeBookmarkBackup_Log.log"


$ErrorActionPreference = "Stop" # Make most script errors terminating

Function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    
    # Write to log file
    try {
        $logEntry | Out-File -FilePath $scriptLogFilePath -Append -Encoding UTF8 -ErrorAction Stop
    } catch {
        # If logging to the primary file fails, write an error to the console.
        Write-Warning "Failed to write to log file '$scriptLogFilePath'. Error: $($_.Exception.Message)"
    }
    
    Write-Host $logEntry
}

try {
    Write-Log -Message "Script started. Version 2.0"

    # --- 1. Detect Logged-in User ---
    Write-Log -Message "Attempting to detect the active user via explorer.exe process..."
    $explorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($null -eq $explorerProcess) {
        Throw "Could not find an active explorer.exe process. Cannot determine the logged-in user."
    }

    $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner
    if ($null -eq $ownerInfo -or [string]::IsNullOrEmpty($ownerInfo.User)) {
        Throw "Could not retrieve owner information for the explorer.exe process."
    }
    
    $loggedInUsername = $ownerInfo.User
    $userDomain = $ownerInfo.Domain

    # Check for system accounts which should not be targeted
    if ($loggedInUsername -eq 'SYSTEM' -or $loggedInUsername -eq 'LOCAL SERVICE' -or $loggedInUsername -eq 'NETWORK SERVICE') {
        Throw "Detected system account ($loggedInUsername) as owner. This script must target a standard user."
    }
    Write-Log -Message "Successfully detected user: $userDomain\$loggedInUsername"

    # --- 2. Construct and Verify Paths ---
    $userProfilePath = "C:\Users\$loggedInUsername"
    if (!(Test-Path -Path $userProfilePath -PathType Container)) {
        Throw "The determined user profile path does not exist: '$userProfilePath'"
    }

    # Source Path for Chrome Bookmarks
    $chromeBookmarksPath = Join-Path -Path $userProfilePath -ChildPath "AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    if (!(Test-Path -Path $chromeBookmarksPath -PathType Leaf)) {
        Throw "Chrome Bookmarks file not found at '$chromeBookmarksPath'."
    }
    Write-Log -Message "Source file found: $chromeBookmarksPath"
    
    # Destination Path
    $destinationBase = Join-Path -Path $userProfilePath -ChildPath $oneDriveRootFolderName | Join-Path -ChildPath $oneDriveBackupSubfolder | Join-Path -ChildPath $backupJobFolderName
    
    # Verify/Create Base Destination Path
    if (!(Test-Path -Path $destinationBase -PathType Container)) {
        Write-Log -Message "Base destination path '$destinationBase' does not exist. Creating it now."
        try {
            New-Item -Path $destinationBase -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Log -Message "Successfully created destination base path."
        } catch {
            Throw "Failed to create destination directory '$destinationBase'. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Log -Message "Verified destination base path: $destinationBase"
    }

    # --- 3. Create Date-Stamped Backup Folder ---
    $backupDate = Get-Date -Format "MM-dd-yy"
    $backupFolderName = "$($backupDatePrefix)_$backupDate"
    $backupFolderFullPath = Join-Path -Path $destinationBase -ChildPath $backupFolderName

    if (!(Test-Path $backupFolderFullPath)) {
        New-Item -ItemType Directory -Path $backupFolderFullPath -Force | Out-Null
        Write-Log -Message "Created new backup folder: $backupFolderFullPath"
    }

    # --- 4. Copy the Bookmarks File ---
    $destinationFile = Join-Path -Path $backupFolderFullPath -ChildPath "Bookmarks"
    Write-Log -Message "Copying Chrome Bookmarks to '$destinationFile'..."
    try {
        Copy-Item -Path $chromeBookmarksPath -Destination $destinationFile -Force -ErrorAction Stop
        Write-Log -Message "Successfully copied Bookmarks file."
    } catch {
        Throw "Failed to copy Bookmarks file. Error: $($_.Exception.Message)"
    }

    # --- 5. Clean Up Old Backups ---
    Write-Log -Message "Cleaning up old backups in '$destinationBase', keeping the newest $maxBackupRetentionCount."
    try {
        # Get all folders matching the naming pattern, sort by creation time (newest first)
        $folders = Get-ChildItem -Path $destinationBase -Directory |
                   Where-Object { $_.Name -match "^$([regex]::Escape($backupDatePrefix))_\d{2}-\d{2}-\d{2}$" } |
                   Sort-Object CreationTime -Descending

        if ($folders.Count -gt $maxBackupRetentionCount) {
            $foldersToDelete = $folders | Select-Object -Skip $maxBackupRetentionCount
            Write-Log -Message "Found $($folders.Count) total backups. Deleting $($foldersToDelete.Count) older folder(s)."
            
            foreach ($folder in $foldersToDelete) {
                Write-Log -Message "  -> Deleting: $($folder.FullName)"
                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Continue
                if ($?) {
                    Write-Log -Message "  -> Successfully deleted."
                } else {
                    Write-Log -Message "  -> WARNING: Failed to delete $($folder.FullName). It may be in use."
                }
            }
        } else {
            Write-Log -Message "Found $($folders.Count) backup(s). No cleanup needed."
        }
    } catch {
        # This will catch errors from Get-ChildItem, but not from Remove-Item (due to -ErrorAction Continue)
        Write-Log -Message "WARNING: An error occurred during the cleanup process: $($_.Exception.Message)"
    }

    Write-Log -Message "Script finished successfully."
    Exit 0

} catch {
    # This top-level catch block handles any terminating errors from the 'try' block.
    $errorMessage = "FATAL SCRIPT ERROR: $($_.Exception.Message)"
    # Check if the error has line number info
    if ($_.InvocationInfo) {
        $errorMessage += " at line $($_.InvocationInfo.ScriptLineNumber)."
    }
    Write-Log -Message $errorMessage
    Exit 1 # Exit with an error code
}