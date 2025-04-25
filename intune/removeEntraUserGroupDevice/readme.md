# Remove-Entra-User-Group-Device 

This remediation script makes a Microsoft Graph call to a specified group (target users), and deletes matching local user folders from a target device — except for the device's primary user, if the primary user is a member of that group.

This is useful for wiping sensitive entra user group data from devices while preserving the primary user's data as a safeguard. If a primary user should no longer be tied to the device, they should be reassigned first.

# Steps:
1. Pre-Install/check for `NuGet` and `Microsoft.graph.authentication` 
2. Authenticate with graph `Connect-MgGraph` 
3. Fetch all users in the target group, format their UPNs to match local folder naming conventions, and store them in memory.
4. Retrieve the device hostname and format it for Graph/Intune lookup.
5. Query Graph for the device's primary user using the hostname.
6. For each user from the target group, check if they match the primary user. If not, delete the corresponding local user folder.



# Endpoints needed:  
- Get users in a group
```powershell
$usersInGroup= "https://graph.microsoft.com/v1.0/groups/$GroupId/members?`$select=userPrincipalName"
```

- Get device primary user
```powershell
$deviceAndOwnerUrl = "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$hostname'&`$expand=registeredOwners(`$select=userPrincipalName)"

```

# Setup requirements
- An Entra app with appropriate read permissions for silent authentication.

- Graph authentication module has to be installed on target device in powershell folder since the target device runs this via the intune managment extension, and needs to authenticate to check.    C:\Program Files\WindowsPowerShell\Modules

- Alternative: If Graph modules are not deployed to endpoints, you can refactor the script to use Invoke-WebRequest and manual API authentication.  


# Caution
- Primary User Inheritance Risk:
If a device was inherited from another user and the primary user in Entra isn't updated, the script could accidentally delete the active user’s data.

- The remediation can also fail to delete users data folders if a users file is in use or fails to close. For example in the logging version of the remediation `FAILED to remove 'C:\Users\FirstName.LastName': The process cannot access the file 'UsrClass.dat' because it is being used by another process.`

- Lastly, ensure your Graph application is granted only the minimum necessary read permissions. Although this script runs briefly through the Intune Management Extension on the device, a client secret could still be intercepted by an attacker during that short window.


# Next Steps
Currently this uses `Remove-Item` to remove the users local data folder. Next I want to delete the profile as well doing something like this to ensure no remnants of the account exist on that device. 

In my head it would be adding the logic like this to the current script.
```powershell
$profile = Get-WmiObject Win32_UserProfile | Where-Object { $_.LocalPath -like "*FirstName.LastName*" }

if ($profile) {
   try {
        $profile.Delete()
        Write-Host "Profile deleted successfully."
    } catch {
        Write-Host "Failed to delete profile: $_"
    }
} else {
    Write-Host "Profile not found."
}
```

# removeEntraUserGroup_LOGS.ps1
This script has logging for testing when you deploy to endpoints. 