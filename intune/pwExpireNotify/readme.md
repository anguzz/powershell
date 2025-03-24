# Overview
This Intune package proactively informs users when their passwords are nearing expiration by leveraging Microsoft Graph API calls. By fetching the last password change date for the signed-in user and comparing it with your organization’s password policy, this tool ensures that users are aware of the impending need to update their passwords. The process is automated to operate seamlessly in the background, minimizing disruptions while enhancing security compliance across managed devices. The package is specifically designed to be deployed via Intune, ensuring a straightforward integration into existing enterprise management workflows.

# Features
- Automatically fetches the currently signed-in user's UPN.
- Uses Graph API to retrieve the last password change date.
- Compares this date against your organization's password policy to determine if the password is nearing expiration.
- Checks if the currently logged-in user account is enabled or disabled, with logic to handle disabled accounts in notifications.
- Stores the API token in system environment variables `GRAPH_PW_EXPIRE_TOKEN`, enhancing security by restricting token access. 

# Usage
- Set your `$userPrincipalName` variable by changing the `$domainEmailExtension`  in the `checkExpire.ps1` script
- Set your organization's password expiration interval in the script,  `$PasswordPolicyInterval = 90` in the `checkExpire.ps1` script
- Add an `$AccessTokenString`  with the appropiate read permissions in the in `install.ps1` script
- Set the `$destinationPath` variable used in all 3 scripts `detection.ps1` `install.ps1` and `uninstall.ps1` files where the expirationCheck task script will be saved. 

# Authentication
This script utilizes system-level environment variables to securely store the API token where users cannot access , protecting it from unauthorized access and simplifying its rotation. Ensure your users do not have access to system level variables. It requires device authentication and should be executed with permissions adequate for reading user profiles. It is intended for deployment on managed devices but can be adapted for other setups by configuring a Graph app with the necessary permissions. Ensure your access token only has limited read access to increase security. 

# Deployment 
- Deploy via Intune as an application. Call the `install.ps1` file after setting the appropiate variables. 
- The `checkExpire.ps1` script is copied to the target device as `checkExpire.ps1` and placed in a secure folder after you set a destination path. 
-  It is executed as a scheduled task set up through the `install.ps1` script with system-level access to ensure it can access the secured API token.
- Installation success is confirmed by the creation of a log file at `C:\$desintationPath$\installLog.txt` which can be checked to verify correct installation in `detection.ps1`.

- Only installs the necessary Microsoft.Graph modules for device authentication on the target device to minimize module footprint.

# Notifications 
Notifications are enhanced with the `System.Windows.Forms.LinkLabel` class in the `popup.ps1` file, supporting hyperlinks and customizable UI elements such as font sizes and popup dimensions.

# Script Details

- `install.ps1`: Handles the setup of the directory, file copying, system variable creation and scheduled task registration. 
- `uninstall.ps1`: Removes the scheduled task, directory, modules, and all its contents for a clean uninstallation.  
- `detection.ps1`: Checks for installation success by verifying the presence of the task being succesfully created, meaning the install went through  
#### Files Folder
- `checkExpire.ps1`: Connects to Microsoft Graph, checks password expiration based on the set policy interval, and calls notifications accordingly. 
- `popup.ps1`: Uses the `System.Windows.Forms.LinkLabel` module to call a popup informing the user to reset their password.



# Run commands
- Installer `powershell -ex bypass -file install.ps1`
- Uninstaller `powershell -ex bypass -file uninstall.ps1`
