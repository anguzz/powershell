
# Outlook Signature Manager

Deploy company-branded Outlook signatures via Intune.

This solution lets you centrally manage and push Outlook signatures across your organization using a Win32 app deployment. The embedded image is Base64-encoded to ensure consistent rendering across devices and avoid mail firewall issues. User personalization is handled dynamically using Entra ID attributes.

---

## Overview

- Detects the currently signed-in user via the `explorer.exe` process.
- Queries Entra ID to retrieve user attributes using Microsoft Graph.
- Builds a personalized signature using those attributes.
- Writes the signature to the appropriate local Outlook directories.
- Sets the default signature via registry keys.

---

## Requirements

- An Entra app registration with **User.Read.All** or equivalent Graph API read permissions.
- Populate the following variables in `install.ps1`:

```powershell
$tenantID          = "<your-tenant-id>" 
$clientID          = "<your-client-id>" 
$clientSecretValue = "<your-client-secret>"  
```

⚠️ Warning *While storing credentials in the script isn't best practice, this script runs under the Intune Management Extension and the secret is cleared post-execution. Use a dedicated app registration with minimum required permissions to reduce risk.*

---

## Variable Setup

1. Use `base64.ps1` to generate a Base64-encoded logo string and paste it into `Standard.htm`.
2. Add your company name to `Standard.txt` and `Standard.htm`.
3. Replace the footer link in `Standard.htm` with your organization’s URL. 


---

## Deployment Steps

1. Package the project using **IntuneWinAppUtil**.
2. Upload the resulting `.intunewin` package to Intune.
3. Configure the app using the details below.

### Install / Uninstall Commands

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
powershell.exe -ExecutionPolicy Bypass -File .\uninstall.ps1
```

### Detection Rule

Use `detection.ps1` to confirm successful deployment by checking for the signature path.

---

## Registry Configuration

The script sets default signatures by modifying this path:

```
HKEY_USERS\<userSID>\Software\Microsoft\Office\<OutlookVersion>\Common\MailSettings
```

It sets the following values:

```powershell
$signatureName = "Company_Standard"
$OutlookVersionForRegistry = "16.0"

$loggedOnUser = (Get-WmiObject -Class Win32_ComputerSystem).UserName

try {
    $ntAccount = New-Object System.Security.Principal.NTAccount($loggedOnUser)
    $userSID = $ntAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
} catch {
    Write-Error "Failed to resolve SID for $loggedOnUser. $_"
    exit 1
}

$registryPath = "Registry::HKEY_USERS\$userSID\Software\Microsoft\Office\$OutlookVersionForRegistry\Common\MailSettings"

try {
    Write-ColoredHost "Setting default signature for new emails and replies/forwards..." -ForegroundColor $ColorInfo
    Set-ItemProperty -Path $registryPath -Name "NewSignature" -Value $signatureName -ErrorAction Stop
    Set-ItemProperty -Path $registryPath -Name "ReplySignature" -Value $signatureName -ErrorAction Stop
    Write-ColoredHost "Default signature set successfully." -ForegroundColor $ColorSuccess
} catch {
    Write-Error "Failed to set default signature in registry. Error: $($_.Exception.Message)"
}
```

---

## Project Structure

```
OutlookSignatureManager/
├── base64.ps1           # Encodes images to Base64
├── detection.ps1        # Intune detection script
├── install.ps1          # Installs signature
├── uninstall.ps1        # Uninstalls signature
└── Signatures/
    ├── Standard.htm     # HTML signature with Base64 image
    ├── Standard.rtf     # RTF version
    ├── Standard.txt     # Plain text version
    └── Standard_files/  # Supporting assets (if any)
```

---

## Notes

- Supports **Outlook desktop only** (no web/mobile support).
- Signature updates require re-deployment.
- Test with a few pilot devices before pushing to production.

---

## Preview

![signature_screenshot](https://github.com/user-attachments/assets/fd8eb1a2-9b99-499b-95c9-f92ddc3b6fdb)
