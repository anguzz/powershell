## PowerShell Script: Add Current logged in user to Local Administrators

This script identifies the currently logged-in user and adds them to the local "Administrators" group on their current device. It is intended for deployment via Microsoft Intune.

This is useful when you want to add a user to a local admin group on a single device without assigning them a broader administrative role through Entra RBAC.


### Requirements
- 64-bit PowerShell: This script must run in a 64-bit PowerShell host. The Add-LocalGroupMember cmdlet it uses is not available in the 32-bit (x86) environment.

### Functionality Overview

1) Identifies User: Finds the active user's UPN by checking the owner of the `explorer.exe` process.

2) Grants Admin Rights: Adds the user `(AzureAD\UserUPN)` to the local "Administrators" group.

3) Logs Actions: Records a full transcript of its operations to `C:\logs\AddLocalAdmin.log` for troubleshooting.

4) Error Handling: Exits with status 0 on success and 1 on failure.