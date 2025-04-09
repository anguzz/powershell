# VMware Horizon Component Uninstall Script

## Overview

This PowerShell package automates the removal of specific VMware Horizon components from a Windows system. It is designed to be run silently, for example, via deployment tools like Intune or SCCM.

## Key Actions

1.  **Logging:** Records all actions with timestamps to:
    * The console/standard output (visible in deployment tool logs).
    * A local file: `C:\Temp\Horizon_Uninstall_Log.txt` (path is configurable).

2.  **Process Termination:** Stops a predefined list of VMware Horizon-related processes (`vmware-view`, `vmware-remotemks`, etc.)

3.  **Application Discovery:** Searches the Windows Registry (`HKLM:\...Uninstall`) to find the uninstall commands for the target applications listed in the script.

4.  **Silent Uninstallation:** Executes the discovered uninstall commands using parameters intended for silent operation (`/silent`, `/qn`) and **attempts to suppress automatic reboots** (`/norestart`, `/REBOOT=ReallySuppress`).

5.  **Handles Uninstaller Types:** Includes logic to correctly format arguments for both MSI (`msiexec.exe`) and EXE uninstallers, prioritizing known switches for the Horizon Client `.exe`.

## Configuration

You can modify these variables at the top of the script:

* `$LogFilePath`: Sets the path for the text log file.
* `$ApplicationsToRemove`: An array of strings specifying the display names of the Horizon components to uninstall. Wildcards (`*`) are supported.
* `$ProcessesToStop`: An array of strings specifying the process names to stop before uninstalling.

## Important Notes

* **Reboot Suppression:** The script actively tries to prevent the system from rebooting during the uninstall process. However, it **cannot guarantee** a reboot will be avoided if an uninstaller ignores the suppression flags or if Windows flags a reboot as necessary after component removal (Exit code 3010 will be logged in this case).
* **Administrator Privileges:** The script requires administrative rights to terminate processes, access the registry, and run uninstallers.

## Usage

Run the script with Administrator privileges on the target Windows machine where Horizon components need to be uninstalled.