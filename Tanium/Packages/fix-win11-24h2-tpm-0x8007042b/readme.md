# In-Place Upgrade Failures 23H2 to 24H2 : Tanium Remediation Guide

## Overview

This guide documents a remediation workflow for Windows in-place upgrade failures hitting:

```
0x8007042b
```

during **Windows 11 feature upgrades (such as 23H2 -> 24H2)** when deployed through **Tanium Deploy**.

The goal is to automate a commonly used manual fix and make it repeatable across endpoints using Tanium packages.

The original manual remediation involves:

**On installation media**

* Delete:

```
\sources\replacementmanifests\tpmdriverwmi-replacement.man
```

**On the source system**

* Edit:

```
C:\Windows\WinSxS\migration.xml
```

* Remove `<file>` entries referencing:

```
microsoft-windows-tpm-driver-wmi
```

* Delete the failed upgrade cache:

```
C:\$WINDOWS.~BT
```

* Disconnect the system from the network and restart the upgrade.

This guide adapts those steps so they can be **automated and deployed through Tanium**, allowing affected systems to be remediated and retried through the normal **Pre-cache -> Compat Scan -> Upgrade Trigger** workflow.


---

# Targeting Information

Example Tanium query used to locate affected systems:

```sql
Get Computer Name and Operating System and Deploy - Deployments?maxAge=60 matches "^252\|.*\|Not Applicable(\|.*)?$" and Operating System Build Number?maxAge=900 from all machines with Deploy - Deployments matches "^252\|.*\|Not Applicable(\|.*)?$"
```

---

# Main Issue

Two conditions typically exist on failing systems:

1. **Migration failure during upgrade**
2. **Tanium package status stuck as Installed instead of Update Eligible**

Both issues must be addressed.

---

# What the Failure Looks Like

Panther logs can be exported through Tanium. These are copies from:

```
C:\Windows\Panther
```

Example export location:

```
C:\Users\Angel.Santoyo\Downloads\emg-fbm_f1ltks{date}\software_manager\software-management-logs\{object_id}\WinIPU\Panther
```

Primary log:

```
setuperr.log
```

Example failure:

```log
2026-02-10 14:23:55 Error SP Operation failed: Offline portion of machine-specific and machine-independent apply operations. Error: 0x8007042B
2026-02-10 14:23:55 Error SP Cannot revert execution of operation 100 (Add boot entry for C:\$WINDOWS.~BT\NewOS\WINDOWS)
```

This occurs during the **SAFE_OS -> MIGRATE_DATA** portion of Windows Setup.

---

# Suspected Cause

The failure appears tied to the **TPM-Driver-WMI migration component**.

Working theory:

* Windows Setup attempts to migrate `microsoft-windows-tpm-driver-wmi`
* Migration state or replacement manifest causes Setup failure
* Failed upgrade cache persists across retries

Fix strategy:

1. Remove TPM migration references from the upgrade path
2. Clear the failed upgrade cache
3. Restage the upgrade so Tanium sees the device as eligible again

---

# Restaging the Update

If the OSD registry state is stuck as **Upgrade In Progress**, the deployment will never trigger again.

Query:

```
Get Registry Value Data[HKEY_LOCAL_MACHINE\Software\Tanium\Tanium Client\OSD, Status] from all entities
```

Set the registry value using a **Registry - Set Value** package:

```
HKEY_LOCAL_MACHINE\Software\WOW6432Node\Tanium\Tanium Client\OSD\Status
```

Set value:

```
Compat Scan OK
```

Effect:

* Overwrites `Upgrade In Progress`
* Allows the device to show as **Update Eligible**
* Allows redeployment through Tanium

---

# Fixing `0x8007042b`

## Remediation Summary

The remediation performs four actions:

1. Remove TPM migration entries from
   `C:\Windows\WinSxS\migration.xml`
2. Delete failed upgrade cache
   `C:\$WINDOWS.~BT`
3. Modify installation media so Setup does not reintroduce TPM migration rules
4. Redeploy through Tanium using the edited ISO

---

# Step 1: Prepare Installation Media

Extract the Windows ISO.

Delete the following file:

```
\sources\replacementmanifests\tpmdriverwmi-replacement.man
```

This prevents Setup from reintroducing the TPM migration behavior.

---

## Rebuild the ISO

After editing the files, rebuild the ISO.

Example using `oscdimg`:

```powershell
.\oscdimg -m -o -u2 -udfver102 `
-bootdata:2#p0,e,b"C:\ISO\boot\etfsboot.com"#pEF,e,b"C:\ISO\efi\microsoft\boot\efisys.bin" `
"C:\ISO" `
"C:\ISO\Win11_24H2_fixed.iso"
```

The rebuilt ISO should be used as the **source for the Tanium Deploy package**.

---

# Step 2: Endpoint Remediation

Run the remediation script:

```
Invoke-TPM_Migration_Remediation.ps1
```

This script performs two tasks.

### Remove TPM Migration Entries

File modified:

```
C:\Windows\WinSxS\migration.xml
```

Remove entries containing:

```
microsoft-windows-tpm-driver-wmi
```

---

### Clear Failed Upgrade Cache

Delete:

```
C:\$WINDOWS.~BT
```

This ensures Setup does not reuse a failed upgrade state.

---

# Step 3: Tanium Package

Create a remediation package.

### Package Name

```
Invoke TPM Migration Remediation
```

### Run Command

```text
cmd.exe /c powershell.exe -ExecutionPolicy bypass -WindowStyle Hidden -NonInteractive -NoProfile -File Invoke-TPM_Migration_Remediation.ps1
```

Target devices confirmed to be failing with:

```
0x8007042b
```

---

# Step 4: Retry the Upgrade

Once remediation completes and OSD status is reset, rerun the **standard Tanium upgrade flow**.

Current Phase 3 arguments already include the correct configuration:

```powershell
$SetupArgs = @(
    '/auto','Upgrade'
    '/NoReboot'
    '/Quiet'
    '/DynamicUpdate','disable'
    '/ShowOOBE','none'
    '/Telemetry','disable'
    '/Uninstall','enable'
    '/CopyLogs',"$copyLogPath"
    '/Compat','IgnoreWarning'
)
```

Disabling Dynamic Update prevents Setup from downloading replacement manifests that could reintroduce the TPM migration rule.

---

# Recommended Workflow

## Admin Side

```
1. Extract Windows ISO
2. Delete tpmdriverwmi-replacement.man
3. Rebuild ISO with oscdimg
4. Upload edited ISO into Tanium Deploy package
```

---

## Endpoint Side

```
1. Run TPM migration remediation package
2. Reset OSD status to Compat Scan OK
3. Retry normal Tanium upgrade flow
4. Review Panther logs if the upgrade fails again
```

---

# Other Failure Types Seen

Some devices may fail for unrelated reasons:

| Issue                       | Fix                      |
| --------------------------- | ------------------------ |
| Detection not met           | Rerun compatibility scan |
| System requirements not met | Hardware replacement     |

These are outside the scope of this guide.

---

# Disclaimer

This remediation workflow is currently in **late-stage testing**.

The remediation logic and scripts were developed to address the `0x8007042b` migration failure. Phase 1 and Phase 2 remediation components were completed and validated in testing environments, but the full Phase 3 deployment results could not be validated at scale before a role transition.

The remediation packages and upgrade process have been handed off to another system administrator for final deployment.

The intent of this document is to provide a **repeatable starting point for other administrators encountering this issue**. Improvements or refinements are encouraged if further testing identifies additional edge cases.

---

# Sources

[https://www.reddit.com/user/Zhlkk/](https://www.reddit.com/user/Zhlkk/)

[https://learn.microsoft.com/en-us/answers/questions/5649780/windows-11-education-23h2-to-25h2-upgrade-fails-tp](https://learn.microsoft.com/en-us/answers/questions/5649780/windows-11-education-23h2-to-25h2-upgrade-fails-tp)

[https://windowsreport.com/windows-10-update-error-0x8007042b-fix/](https://windowsreport.com/windows-10-update-error-0x8007042b-fix/)

[https://www.yourwindowsguide.com/2025/12/25h2-repair-install-failed.html](https://www.yourwindowsguide.com/2025/12/25h2-repair-install-failed.html)

[https://www.thewindowsclub.com/fix-windows-10-update-error-0x8007042b](https://www.thewindowsclub.com/fix-windows-10-update-error-0x8007042b)

[https://pete.akeo.ie/2025/06/downloading-oscdimgexe-from-microsoft.html](https://pete.akeo.ie/2025/06/downloading-oscdimgexe-from-microsoft.html)

[https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)

[https://help.tanium.com/bundle/ug_deploy_cloud/page/deploy/use_case_managing_windows_upgrades.html](https://help.tanium.com/bundle/ug_deploy_cloud/page/deploy/use_case_managing_windows_upgrades.html)

