# Outlook Signature Manager
Deploy Outlook company signatures via Intune.

This project lets you centrally manage and push Outlook signatures across your org using a Win32 app deployment. The image is embedded using Base64 for consistent rendering across devices and mail clients. It includes a utility tool to add embedded Base64 images that don't get blocked by mail firewall rules.

The script detects the current user from the running `explorer.exe` process and queries their UPN in Entra ID. It then dynamically builds a signature using the user's Entra attributes—making the deployment fully personalized per user.

# Requirements

This script requires an Entra app registration with the appropriate read permissions to query user attributes.

Make sure to populate the following variables in `install.ps1`: 

```powershell
$tenantID          = "" 
$clientID          = "" 
$clientSecretValue = ""  
```

-  Caution: While storing credentials in a script isn’t best practice, the risk is minimal here since it's deployed via the Intune Management Extension and the data is cleared shortly after execution. Ensure you have a seperate access token and application with minimal read permissions to minimize risk. 

# Variable setup
1) Use base64.ps1 to generate Base64 image strings for HTML embedding, copy paste this string to where I currently have a base64 string on `Standard.htm`
2) Add company name in `Standard.txt` and at the bottom of `Standard.htm`
3) Add href to your organizations link at the bottom of `Standard.htm` where I currently filled it in with this github link.

# Deployment
1) Package the script and signature folder using the IntuneWinAppUtil tool.
2) Upload install.intunewin to Intune and configure:


### scripts
- `base64.ps1` - Encodes image assets into Base64
- `detection.ps1` - Detection script for Intune to validate deployment 
- `install.ps1` - Installs signature and dependencies at `C:\Users\Angel.Santoyo\AppData\Roaming\Microsoft\Signatures` and generates a log file at `C:\Temp\IntuneSignatureManagerForOutlook-Graph-log`
- `uninstall.ps1` - Uninstalls signature at `C:\Users\Angel.Santoyo\AppData\Roaming\Microsoft\Signatures` and generates a log file at `C:\Temp\IntuneSignatureManagerForOutlook-Graph-log`


### Install commands: 
1) powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
2) powershell.exe -ExecutionPolicy Bypass -File .\uninstall.ps1

- Detection script: Use detection.ps1 to verify success by testing for filepath

# Directory structure 
``` powershell
OutlookSignatureManager/
├── base64.ps1           # Encode images to Base64
├── detection.ps1        # Intune detection logic
├── install.ps1          # Main deployment script
├── uninstall.ps1        # Cleans up signature
└── Signatures/
    ├── Standard.htm     # HTML signature (with embedded image)
    ├── Standard.rtf     # RTF version
    ├── Standard.txt     # Plain text version
    └── Standard_files/  # Asset folder (e.g. logo)
```

# Notes
- Works for Outlook desktop clients (no effect on mobile/web).
- Signature updates require re-deployment.
- Be sure to test before pushing org-wide.

# Preview 

![signature_screenshot](https://github.com/user-attachments/assets/fd8eb1a2-9b99-499b-95c9-f92ddc3b6fdb)
