

# Overview
This package contains a collection of templates that perform application installations directly on devices, ideal for scenarios where Intune installations are hindered by slow network conditions. It optimizes both disk space usage and deployment speed by handling installations locally, which can significantly reduce bandwidth consumption. It has multiple uninstall and install scripts for different scenarios/use cases. 

## Setup
- Copy the IntuneAppTemplate directory and rename it to match your application.
- Place your installer files (e.g., .exe or .msi) in the Files folder within the script directory.
- Modify the install and uninstall scripts to adjust variable names and include the appropriate install flags for your .exe or .msi files.
- Adjust the install and uninstall scripts for things like the variable names to have these value and also install flags on the exe/msi which both differ.
- Execute winutil on install.ps1 to prepare for deployment


## Install scripts
Two installs scripts are provided
 - `install_msi.ps1` which showcases the logic for installing an msi via powershell silently with the appropiate msi flags
 
 - Standard MSI flags
`https://learn.microsoft.com/en-us/windows/win32/msi/standard-installer-command-line-options`

 - install_exe.ps1 which showcases the logic for installing an exe via powershell silently with appropiate or generic exe flags.

For exe files it will differ per file but the current commands in the install.exe has generic flags commonly supported by well known applications. 

## Uninstall scripts
Two uninstall scripts are provided
 - `uninstall_exe.ps1` calls the exe directly and silently to uninstall an application, its used by copying the targetted app and calling an exe to uninstall against it. This works well when you have older app versions that do not want to uninstall or update, you call the exe with the uninstall flags after dumping it on the machine then call it again with the install flags.

 - `uninstall.ps1` will loop through the software registry and look for the uninstall code based on the apps display name, works well when you do not want to target on a specific msi string

## Detection scripts
- `detection1.ps1` checks if a specific application is installed at a designated file path and verifies that its version meets or exceeds a specified target version
- `detection2.ps1` checks if a specified application with the required version is installed on the system by searching the Windows registry for its uninstall information. 

### install commands 
- `powershell -ex bypass -file install.ps1`  General install command

- `powershell.exe -ex bypass -windowstyle hidden -File install.ps1 ` Hide powershell window (needed for when installed in user context not system)

 - `%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\install.ps1` (ensure the application launches in 64 bit powershell)

- `powershell -ex bypass -file uninstall.ps1`  Run the uninstaller

