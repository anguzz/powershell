

# Device-based licensing for Microsoft 365 Apps intune application
### Modifies the follwing path. 
- Path: `HKLM\SOFTWARE\Microsoft\Office\ClickToRun\Configuration`
- Key: `SharedComputerLicensing` (REG_SZ / string) 

### Scripts 
- `install.ps1` Sets SharedComputerLicensing to 0 to enforce user-based licensing.
- `uninstall.ps1` Resets SharedComputerLicensing to 1, which is Microsoft's default for shared device licensing.
- `detection.ps1`   Detects whether the registry value is correctly set to either 0 or 1. If set to anything else or missing, Intune will trigger remediation.

> Note: This registry value is not present by default unless Microsoft 365 Apps was installed with shared computer/device licensing enabled. This serves as a way to change the licensing without having to uninstall the application to enable/disable features needed by shared or user based licensing. 

# Intune Deployment commands
To avoid writing to `HKLM:\SOFTWARE\WOW6432Node\` ensure you install/uninstall in 64 bit powershell. 

  - Install `%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\install.ps1`
  - Uninstall `%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\uninstall.ps1`


# References:
- Microsoft configuration file for [office deployment tool setting XML/Registry](https://learn.microsoft.com/en-us/microsoft-365-apps/licensing-activation/overview-shared-computer-activation).  

- Colorado State University – [Office Device-Based Licensing Info](https://help.mail.colostate.edu/officedbs.aspx#:~:text=Looking%20at%20the%20Windows%20Registry%3A%201%20Open%20Regedit,value%20is%20set%20to%201%20as%20shown%20below%3A)




