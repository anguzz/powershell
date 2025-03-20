# Disclaimer
This project has been discontinued due to deployment challenges. The `Connect-MgGraph` module currently requires interactive authentication, which makes it unsuitable for silent installations or for fetching password expiration data without user interaction. Although the script functions well for individual testing on a personal machine, deploying it on a larger scale within an enterprise environment is not feasible without interactive input, or hard coding in authentication which is not secure. 

For personal or small-scale enterprise use, it is possible to configure a Graph app with read access to manage authentication more securely through hardcoded values in the script however, deploying this solution to client devices with variables for Entra read access poses security risks and is not advised. I am looking into alternatives but this serves as a proof of concept that you can setup client side notifications for password expirations on user machines with graph. 


# Overview
This PowerShell package enhances security for organizations using Microsoft 365 by checking the password expiration status of the current user and alerting them with a popup message. It automatically attaches the domain's standard email to the user's UPN to make a Graph API call and check the last password change date against the organization's password policy.  

![image](https://github.com/user-attachments/assets/306360fb-6e4a-42b7-afb3-44854191115b)


# Features
- Automatically fetches the currently signed-in user's UPN.
- Makes a Graph API call to retrieve the last password change date.
- Compares this date with your organization's password policy to determine if the password is nearing expiration.

# Usage
- Replace `$userPrincipalName = "$currentUser@email.com"` with your domain's standard naming convention. 
- Set your organization's password expiration interval in the script, e.g., `$PasswordPolicyInterval = 90`

# Authentication
This script requires device authentication and should be executed with permissions adequate for reading user profiles. It is intended for deployment on managed devices but can be adapted for other setups by configuring a Graph app with the necessary permissions.


# Deployment 
Deploy via Intune as an application. The `notify.ps1` script is copied to the target device as `callNotify.ps1` and placed in `C:\pwExpireNotify`. It is executed as a scheduled task set up through the `install.ps1` script. Installation success is confirmed by the creation of a log file at `C:\pwExpireNotify\installLog.txt` which can be checked to verify correct installation in `detection.ps1`

- `C:\pwExpireNotify` can also be used as a detection target to see if the app installed properly. 
- Only installs the Microsoft.Graph.Authentication and Microsoft.Graph.Users modules for device authentication on target device to minimize module footprint for the current user.



# Important
Run under user context to ensure access to the $currentUser environment variable. Powershell modules are also installed under the current user context rather then system. 


# Notifications 
Notifications are sent using the `-ComObject Wscript.Shell` interface.

Here is an example of usage below.

```powershell
$wshell = New-Object -ComObject Wscript.Shell

$wshell.Popup("Operation Completed",0,"Done",0x1)
```

- More info can be found at 
https://learn.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/windows-scripting/x83z1d9f(v=vs.84)?redirectedfrom=MSDN



# Script Details

- `install.ps1`: Handles the setup of the directory, file copying `notify.ps1`, and scheduled task registration.
- `uninstall.ps1`: Removes the scheduled task, directory,modules and all its contents for a clean uninstallation.
- `detection.ps1`: Checks for the installation success by verifying the presence of the directory and script file.
- `notify.ps1`: Connects to Microsoft Graph, checks password expiration based on the set policy interval, and displays notifications accordingly.

# Next steps
- Add update module check on scheduled task so authentication module stays up to date
