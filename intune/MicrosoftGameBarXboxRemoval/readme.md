# Microsoft Game Bar & GameAssist Removal (Intune-Friendly)

Removes and blocks Xbox Game Bar and the associated `Microsoft.Edge.GameAssist` AppX package using Intune. Includes detection/removal scripts and config profile guidance to keep systems clean.

---

##  Overview

Disabling the Game Bar alone isn’t enough — components like `Microsoft.Edge.GameAssist` often remain installed or get reinstalled.

This setup includes:
- A detection script for compliance reporting
- A removal script to uninstall and deprovision related AppX packages
- Configuration profile recommendations to block Game Bar via Intune

---

##  Files

### `detect.ps1`
Detection script for proactive remediation.  
Fails (non-compliant) if `Microsoft.XboxGamingOverlay` is found.
The way this package is designed is a succesfully installed mea
---

### `uninstall.ps1`
Use the intune win app on this file for intune upload. Removes the following packages if present:

```powershell
"Microsoft.XboxGamingOverlay*",
"Microsoft.GameOverlay*",
"Microsoft.XboxGameOverlay*",
"Microsoft.XboxIdentityProvider*",
"Microsoft.XboxSpeechToTextOverlay*",
"Microsoft.Edge.GameAssist*",
"Microsoft.Xbox.TCUI*",
"Microsoft.XboxApp*"
"Microsoft.GamingApp*"

```

##  Intune Config

Use **Settings Catalog** + **Device Restrictions** to block Game Bar:

| Setting                                  | Value  |
|------------------------------------------|--------|
| Allow Game Bar                           | Block  |
| Allow Game DVR                           | Block  |
| Allow Advanced Gaming Services           | Block  |
| Gaming (Settings UI) in Control Panel    | Block  |

---




##  Next steps
Considering implementing Windows defender application control policy for added control and security, though this may be overkill, prevents execution.
