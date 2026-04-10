# Microsoft XPS Document Writer – Intune Remediation Package

## Overview

This Intune package enables the **Microsoft XPS Document Writer** feature on Windows devices. It checks for the presence of the XPS printer and optional features and installs them if missing.

---

## Detection Logic

The detection script checks if the XPS Document Writer is already enabled by:

- Verifying if the optional feature `Printing-XPSServices-Features` is enabled.
- Checking if the printer named **"Microsoft XPS Document Writer"** is installed.

### Output

- Returns `0` if either is present (feature or printer).
- Returns `1` if both are missing (triggering install).

---

## Install Command

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features" -All -NoRestart
```

This enables the Windows optional feature responsible for installing the Microsoft XPS Document Writer printer and related services.

---

## Uninstall Script

Uninstalls the printer and disables any associated Windows optional features:

```powershell
# Remove printer if it exists
Remove-Printer -Name "Microsoft XPS Document Writer"

# Disable features
Disable-WindowsOptionalFeature -Online -FeatureName "Printing-XPSServices-Features" -NoRestart
Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-XPS-Document-Writer-Package" -NoRestart
```

---

## Notes

- The detection logic allows the install to be skipped if the feature or printer is already present.
- A restart is **not** forced during install or uninstall but may be required by Windows.
- You can package this for Intune as a Win32 app with standard detection and remediation workflow.
