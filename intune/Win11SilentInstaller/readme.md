# Windows 11 Upgrade Script – Intune/Local Deployment

This script automates the download and execution of the Windows 11 Installation Assistant and is intended to be an intune remediation.

 1. If build contains 26100(win11+), writes a marker file (deviceCurrentlyWindows11.txt) and exits
 2. If not, continues with update.

## `win11Installer.ps1`

- Creates a working directory at C:\Win11Upgrade

- Deletes any previously downloaded Windows11InstallationAssistant.exe

- Downloads the latest version from Microsoft:

`URL: https://go.microsoft.com/fwlink/?linkid=2171764`
 
## Optional
- To bypass TPM and CPU checks uncomment the following lines in the script, though this is not generally recommended. 
  
  `New-ItemProperty -Path "HKEY_LOCAL_MACHINE\SYSTEM\Setup\MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -PropertyType DWord -Value 1 -Force | Out-Null`

   `New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\PCHC" -Name "UpgradeEligibility" -PropertyType DWord -Value 1 -Force | Out-Null`

- Note: Makes it so we wait on user to restart device. Can remove restart flags to be more aggressive with updates if you don't mind random reboots.  

