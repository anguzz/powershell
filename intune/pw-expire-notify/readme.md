# Password Expiration Notifier for Intune

# Overview
This Intune package proactively informs users when their Azure AD passwords are nearing expiration by leveraging Microsoft Graph API calls. It fetches the last password change date for the signed-in user and compares it with your organization’s password policy. The tool operates seamlessly in the background via a scheduled task, ensuring users receive timely notifications to update their passwords, thus maintaining security compliance across Intune-managed devices.

# Features
- Automatically fetches the currently signed-in user's UPN (requires configuration in `checkExpire.ps1`).
- Uses Microsoft Graph API to retrieve the user's last password change date (`lastPasswordChangeDateTime`).
- Compares this date against your organization's configured password policy interval (`$PasswordPolicyInterval`).
- Checks if the currently logged-in user account is enabled or disabled (`accountEnabled`) via Graph, tailoring notifications accordingly.
- Required PowerShell modules are **bundled** with the package and copied during installation, avoiding runtime downloads.
- Encrypts and stores the Entra App Registration client secret in a machine-level environment variable (`Intune_Desktop_Notifications_Secret`) for secure authentication.
- Creates a scheduled task that runs as the logged-in user at logon to ensure notifications appear in the user's session.
- Task settings ensure it runs even if the network isn't immediately available at logon, retrying later.

![Notification Popup Example](https://github.com/user-attachments/assets/c0b58dce-b996-4fb1-be25-00275ddb8e4d)
![Disabled Account Popup Example](https://github.com/user-attachments/assets/918019eb-0907-441f-b41c-546fc752496d)

# Prerequisites
1.  **Entra ID App Registration:**
    * Create an App Registration in Microsoft Entra ID.
    * Grant it the following **Application** permissions for Microsoft Graph:
        * `User.Read.All` (Required to read `lastPasswordChangeDateTime` and `accountEnabled` for users).
    * Grant Admin Consent for these permissions.
    * Record the **Tenant ID**, **Application (client) ID**, and generate a **Client Secret**.
2.  **AES Encryption Key:**
    * Generate a secure 256-bit AES key and encode it as Base64. You can use PowerShell:
        ```powershell
        $key = New-Object byte[] 32
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($key)
        $base64Key = [Convert]::ToBase64String($key)
        Write-Host "Your Base64 Encoded AES Key: $base64Key"
        ```
    * Store this key securely; it's needed in `install.ps1`.
3.  **Bundled PowerShell Modules:**
    * On a machine with internet access, download the necessary modules and their dependencies. Using `Install-Module` 

    * Copy the resulting module folders (e.g., `Microsoft.Graph.Authentication`, `Microsoft.Graph.Users`) into the `modules` subdirectory of this package source.

# Configuration

1.  **`install.ps1`:**
    * Set `$ClientSecret`: Your Entra App Registration client secret.
    * Set `$Base64AESKey`: The Base64 encoded AES key you generated.
    * *(Optional)* Modify `$clientSecretEnvVarName` if desired (must match `checkExpire.ps1`).
    * *(Optional)* Modify `$destinationPath` (must match `uninstall.ps1` and `detection.ps1`).
    * *(Optional)* Modify `$logFilePath` for installation logs.
2.  **`checkExpire.ps1` (inside the `files` folder):**
    * Set `$tenantID`: Your Entra Tenant ID.
    * Set `$clientID`: Your Entra App Registration Application (client) ID.
    * Set `$clientSecretEnvVarName`: Must match the name used in `install.ps1`.
    * Set `$domainEmailExtension`: The email domain suffix used to construct the UserPrincipalName (e.g., "@yourcompany.com").
    * Set `$PasswordPolicyInterval`: Your organization's password expiration policy in days (e.g., `90`).
    * *(Optional)* Modify `$WarnDaysBeforeExpiration`: How many days before expiration to start showing notifications.
3.  **`uninstall.ps1`:**
    * Ensure `$destinationPath`, `$logFilePath`, `$clientSecretEnvVarName`, and `$modulesToRemove` match the configuration used during installation.
4.  **`files\Logo.png`:**
    * Replace this with your organization's logo. Adjust dimensions in `popup.ps1` and `popup2.ps1` if needed.

# Deployment via Intune (Win32 App)

1.  **Prepare Package:** Ensure your directory structure matches the example below, including the `modules` folder populated from the prerequisites step. Create the `.intunewin` file using the Microsoft Win32 Content Prep Tool.
2.  **Create Intune App:**
    * Upload the `.intunewin` file.
    * **Program:**
        * Install command: `%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\install.ps1`
        * Uninstall command: `%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\uninstall.ps1`
        * Install behavior: **System** (This is crucial for permissions to write to Program Files, ProgramData, set machine environment variables, and create tasks initially).
        * Device restart behavior: No specific action.
    * **Detection Rules:**
        * Use a script detection rule (`detection.ps1`). This script should verify successful installation (e.g., check for the existence of `$destinationPath\checkExpire.ps1`, the scheduled task, or specific content in the install log). Configure the detection script to run as **System** and enforce script signature check **No**.
    * **Dependencies:** None required within Intune if modules are bundled correctly.
    * **Assignments:** Assign to target user or device groups.

# How it Works

-   **Installation (`install.ps1` running as SYSTEM):**
    * Creates the destination folder (e.g., `C:\ProgramData\pwExpireNotifyClient`).
    * Encrypts the provided client secret using the AES key and stores it as a machine-level environment variable.
    * Copies the bundled PowerShell modules from the package's `modules` folder to the system-wide PowerShell module path (`C:\Program Files\WindowsPowerShell\Modules`).
    * Copies the application scripts (`checkExpire.ps1`, `popup.ps1`, etc.) and logo into the destination folder.
    * Creates a scheduled task (`CheckUserPasswordPolicy`) configured to run `checkExpire.ps1` at user logon. The task principal is set to the interactively logged-on user (detected via `explorer.exe` owner) to ensure notifications appear correctly.
-   **Execution (`checkExpire.ps1` running as User via Scheduled Task):**
    * Retrieves the encrypted client secret from the environment variable and decrypts it using the AES key embedded in the script.
    * Connects to Microsoft Graph using the Tenant ID, Client ID, and decrypted Client Secret.
    * Gets the logged-on user's UPN and queries Graph for `lastPasswordChangeDateTime` and `accountEnabled`.
    * Calculates the password expiry date based on `$PasswordPolicyInterval`.
    * If the password nears expiration (within `$WarnDaysBeforeExpiration`) and the account is enabled, triggers `popup.ps1`.
    * If the account is disabled, triggers `popup2.ps1`.
-   **Uninstallation (`uninstall.ps1` running as SYSTEM):**
    * Removes the scheduled task.
    * Removes the application directory (`$destinationPath`).
    * Removes the machine-level environment variable.
    * Removes the specific module folders (listed in `$modulesToRemove`) that were copied during installation from `C:\Program Files\WindowsPowerShell\Modules`.

# Authentication
Authentication to Microsoft Graph uses the Entra App Registration's Client ID and Client Secret. The secret is encrypted using AES-256 and stored in a machine-level environment variable (`Intune_Desktop_Notifications_Secret`) by the installation script (running as System). The `checkExpire.ps1` script (running as the user) retrieves and decrypts this secret at runtime using the key embedded within it. Ensure standard users do not have permissions to modify machine-level environment variables.

# Notifications
User notifications are handled by `popup.ps1` and `popup2.ps1`, utilizing `System.Windows.Forms` to create custom popups. `popup.ps1` includes a hyperlink (e.g., to your password reset portal). UI elements like window size and fonts can be customized within these scripts.

# Script Details

-   `install.ps1`: (Run as System) Handles setup: creates directory, sets encrypted environment variable, copies bundled modules, copies application files, registers the user-context scheduled task via an XML file `CheckUserPasswordPolicy.xml`.
-   `uninstall.ps1`: (Run as System) Handles cleanup: removes scheduled task, application directory, environment variable, and copied module folders.
-   `detection.ps1`: (Run as System) Used by Intune to verify successful installation (e.g., checks for key files or task existence).
-   **`files\` Folder:** Contains files copied to the client.
    -   `checkExpire.ps1`: Core logic - connects to Graph, checks password status, calls appropriate popup. Needs Tenant/Client ID configuration.
    -   `popup.ps1`: Displays the standard "password nearing expiration" notification.
    * `popup2.ps1`: Displays a notification if the user's account is found to be disabled.
    * `Logo.png`: Your company logo displayed in the popups.
-   **`modules\` Folder:** (Populate before packaging) Contains the pre-downloaded PowerShell modules (`Microsoft.Graph.Authentication`, `Microsoft.Graph.Users`, and their dependencies) required by `checkExpire.ps1`.

