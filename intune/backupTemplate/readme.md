# Local C Drive Backup to OneDrive

## Overview
This PowerShell script is designed to automate the process of backing up specific data from the local C drive to a user's OneDrive/Documents directory. It is intended to run in the background silently, managed by Intune or another device management tool, to ensure regular backups of important files without user intervention.

## Features
- **Automated Backup**: Configured to automatically copy data from a specified local folder to a designated directory that is backed up by oneDrive.
- **Logging**: Includes detailed logging of the backup process and errors, stored within the backup directory.
- **Maintenance of Backups**: Automatically maintains the three most recent backups by deleting older ones.


## Setup
1. **Configure Source Directory**: Modify the `$source` variable in the script to point to the local directory you want to back up.
   ```powershell
   $source = "C:\myLocalApp"
2. **Configure One drive Destination Directory**: Modify the `$source` variable in the script to point to the local directory you want to back up.
   ```powershell
   $destinationBase = "C:\Users\$env:USERNAME\OneDrive\Documents\Backups\$folderBackupName"  
   
