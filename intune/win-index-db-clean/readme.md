# Overview
This package offers remediation scripts for managing the size of Windows index database files on endpoints such as desktops, laptops, and servers. These scripts are designed for use with Intune or similar management tools to ensure optimal performance and system efficiency.


### reset.ps1
Resets the windows search manually index by pausing the Windows Search service and deleting the `windows.db` file. Run as admin or with elevated system if pushed out as remediation


```
net stop wsearch
del "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.db"
net start wsearch
```


### rebuild.ps1
This script triggers a rebuild of the Windows Search index by modifying a registry key. This informs the operating system that the Search index setup is incomplete, prompting a rebuild upon the next system restart.


- Creates registry entry at `Computer\HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search` with a key of `SetupCompletedSuccessfully` set to a `DWORD` value of 0.  
- Less intrusive/distruptive then quickly resetting the service and deleting the file
- A system restart is required to apply changes.

### detection.ps1
Detects 
- Adjust the `sizeThreshold` variable to set the desired size limit that triggers remediation.