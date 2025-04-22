# README: CopyBackupToUserOneDrive.ps1 (v1.1)

## Overview

This PowerShell script backs up a specified source folder to the **current logged-in user's OneDrive folder**.

It's designed to be deployed via tools like **Intune** or SCCM and run under the **SYSTEM account**, while still correctly identifying and targeting the active user's profile and OneDrive path.

## Key Features & How it Works

* **Runs as SYSTEM, Targets User:** Solves the common issue where SYSTEM doesn't know the user's path.
    * Finds the active user by checking the owner of the `explorer.exe` process.
    * Dynamically builds the correct path to `C:\Users\<username>\OneDriveFolderName\...\BackupJobName`.
* **Robust Copying:** Uses `Robocopy` for efficient mirroring (`/MIR`).
    * Uses `/COPY:DATSO` flags to copy data, attributes, timestamps, security, and owner info, **avoiding permission errors** related to auditing (`/COPYALL` often fails as SYSTEM).
* **Automatic Cleanup:** Keeps only the most recent `$BackupsToKeep` backup folders (named `<DateFolderNamePrefix>_MM-dd-yy`).
* **Logging:** Creates logs for script actions and Robocopy output within the backup destination and a fallback temp location.

## Setup & Configuration

1.  **Edit Script Variables:** Open the `.ps1` file and modify the variables in the `--- TEMPLATE CONFIGURATION ---` section:
    * `$SourceDirectory`: **REQUIRED** - The folder to back up (Ensure SYSTEM has read access).
    * `$OneDriveFolderName`: **REQUIRED** - The exact name of the OneDrive sync folder (e.g., "OneDrive - Company Name").
    * `$OneDriveRelativePath`: Path within OneDrive for backups (e.g., "Documents\Backups").
    * `$BackupJobName`: A name for this specific backup task.
    * `$DateFolderNamePrefix`: Prefix for the daily folder (e.g., "app_backup").
    * `$BackupsToKeep`: Number of daily backups to retain (e.g., `3`).
2.  **Review Other Options:** Check Robocopy flags and retry settings if needed.

## Deployment (Intune Example)

1.  Go to `Devices` > `Scripts` > `Add` > `Windows 10 and later`.
2.  Upload the configured `.ps1` script.
3.  Settings:
    * Run this script using the logged on credentials: **No** (Essential for SYSTEM context).
    * Enforce script signature check: **No** (Unless signing scripts).
    * Run script in 64-bit PowerShell Host: **Yes**.
4.  Assignments: Assign the script to a **Device Group**.

## Monitoring

Check Intune script status or the log files created in the user's OneDrive backup location (`<DestinationBase>\<DateFolderNamePrefix>_MM-dd-yy\BackupLogs\`) or `C:\Windows\Temp\` if path detection fails early.