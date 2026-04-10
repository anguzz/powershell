
# OneLaunch removal remediation tool

## Overview
This PowerShell script is designed to remove OneLaunch, a commonly identified bloatware, from Windows systems. Unlike traditional methods that rely on MSI uninstall strings, this script uses Where-Object cmdlet to identify and remove OneLaunch based on its display name. This approach ensures it gets removed regardless of specific msi codes that may be changed in future iterations. 

The script is takes inspiration from techniques used in the following resources:

- Threat Remediation Scripts by xephora
`https://github.com/xephora/Threat-Remediation-Scripts/blob/main/OneLaunch/readme.md`

- Lockard Security's Comprehensive Guide to Removing OneLaunch Malware
`https://www.lockardsecurity.com/2024/08/01/removing-onelaunch-malware-a-comprehensive-guide/`


#### Repackageable: 
The script can be repackaged as an application depending on your use case, which will require modification of exit codes in the `remove.ps1` file(flipping them)

# Usage
Script is meant to be used as an intune remediation but can also be used as a app package deployment with a few tweaks. 


