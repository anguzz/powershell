# TeamViewer PSAppDeployToolkit Script

This PowerShell script uses **PSAppDeployToolkit** to install, uninstall, or repair TeamViewer Host with custom pre-install cleanup and post-install assignment. It assumes you cloned PSADT and you had the rest of the directory structure from [PSADT](https://psappdeploytoolkit.com/docs/getting-started/download).

## Features
- Removes previous TeamViewer versions (service stop, silent uninstaller run, leftover folder cleanup).
- Installs `TeamViewer_Host.msi` with a provided `CUSTOMCONFIGID`.
- Runs TeamViewer assignment command post-install.
- Supports **Install**, **Uninstall**, and **Repair** deployment types.
- Fully compatible with PSAppDeployToolkit logging, exit codes, and parameters.

## Usage Examples
```powershell
# Silent install
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Install -DeployMode Silent

# Uninstall
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

# Allow reboot pass-through
powershell.exe -File Invoke-AppDeployToolkit.ps1 -AllowRebootPassThru
```

## Requirements
- **PSAppDeployToolkit** v4.0.6 or later in `./PSAppDeployToolkit/`
- Windows with PowerShell 5.1+
- Updated `ConfigID` and `AssignmentID` in script


# Configuration
- Configure necessary PSADT install variables
```powershell
$adtSession = @{
    # App variables.
    AppVendor = 'TeamViewer SE'
    AppName = 'TeamViewer'
    AppVersion = 'ADD_VERSION_HERE'
    AppArch = ''
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppScriptVersion = '1.0.0'
    AppScriptDate = 'Add_DATE_HERE'
    AppScriptAuthor = 'Angel Santoyo'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = 'TeamViewer Host'
    InstallTitle = 'TeamViewer Host'

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion = '4.0.6'
    DeployAppScriptParameters = $PSBoundParameters
}
```

- Configure teamviewer ID enrollment variables

```powershell
    $ConfigID="ADD_CONFIG_ID_HERE"
    $assignmentID = "ADD_ASSIGNMENT_ID_HERE"
```

## Notes
- Exit codes follow PSAppDeployToolkit conventions.
- Configurable parameters are at the top of the script.
- Licensed under GNU LGPLv3.
- PSAppDeployToolkit docs: [psappdeploytoolkit.com](https://psappdeploytoolkit.com)

## Assignment commands
-  `Start-Process -FilePath "C:\Program Files\TeamViewer\TeamViewer.exe" -ArgumentList "assignment --id $AssignmentIDString` can be used to enroll existing devices outside of PSADT
-  `Start-ADTProcess -FilePath "C:\Program Files\TeamViewer\TeamViewer.exe" -ArgumentList "assignment --id $AssignmentIDString` can be used to enroll existing devices  inside of PSADT 



### Detection.ps1
- Configure `$targetVersion`
- Checks for TeamViewer.exe in standard 32/64-bit install paths, retrieves its file version, and compares it to a target version.
- Returns 0 if versions match, 1 if they don’t or if the file isn’t found.