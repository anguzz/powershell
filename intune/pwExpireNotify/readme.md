# Overview
This Intune package proactively informs users when their passwords are nearing expiration by leveraging Microsoft Graph API calls. By fetching the last password change date for the signed-in user and comparing it with your organization’s password policy, this tool ensures that users are aware of the impending need to update their passwords. The process is automated to operate seamlessly in the background, minimizing disruptions while following security compliance across managed devices. The package is specifically designed to be deployed via Intune, ensuring a straightforward integration into existing enterprise management workflows.

# Features
- Automatically fetches the currently signed-in user's UPN.
- Uses Graph API to retrieve the last password change date.
- Compares this date against your organization's password policy to determine if the password is nearing expiration.
- Checks if the currently logged-in user account is enabled or disabled, with logic to handle disabled accounts in notifications.
- Encrypts and stores the API client secret in system environment variables `encrypted_client_secret` for authentication
- Ensures the scheduled task creation will execute until it has network to make the api call
  
![image](https://github.com/user-attachments/assets/c0b58dce-b996-4fb1-be25-00275ddb8e4d)


![image](https://github.com/user-attachments/assets/918019eb-0907-441f-b41c-546fc752496d)


# Usage
- Set your `$userPrincipalName` variable by changing the `$domainEmailExtension`  in the `checkExpire.ps1` script
- Set your organization's password expiration interval `$PasswordPolicyInterval` in the `checkExpire.ps1` script
- Set the `$destinationPath` variable used in all 3 scripts `detection.ps1` `install.ps1` and `uninstall.ps1` files where the expirationCheck task script will be saved. 
- Set the `$tenantID`, `$clientID` & `$client_secret` in the install.ps1 file
- Add your `logo.png` under files and modify the popup dimensions for it accordingly.

# Authentication
This script utilizes connects to graph `Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $credential` Ensure you setup an entra app with appropiate limited read access. The system-level environment variables to store the client secret where users cannot edit it, protecting it from unauthorized modification. Ensure your users do not have access to edit system level variables. The client secret is encrypted when stored as a system enviroment variable and decrypted during runtime. 

# Deployment 
- Deploy via Intune as an application. Call the `install.ps1` file after setting the appropiate variables. 
- The `checkExpire.ps1` script is copied to the target device as `checkExpire.ps1` and placed in a secure folder after you set a destination path. 
-  It is executed as a scheduled task set up through the `install.ps1` script with system-level access to ensure it can access the graph application.
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
- `popup2.ps1`: Seperate popup that gets called when the users account is locked or not enabled. `https://graph.microsoft.com/v1.0/me?$select=accountEnabled`


# Run commands
- Installer `%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\install.ps1`
- Uninstaller `powershell -ex bypass -file uninstall.ps1`
- Ensure system install with 64 bit powershell installation. 
