
# LAPS Troubleshooting

Occasionally after a Windows build update, the LAPS-managed local admin account may be lost or removed.

If this happens, another local administrator can recreate the missing account to match what’s defined in the policy name, 

For example if you have .\\IT-ADMIN create that account with another local admin then run:

```powershell
Invoke-LapsPolicyProcessing
````

This forces the device to immediately reprocess its LAPS policy and rotate or back up the password if configured correctly.

---

###  Checking LAPS Status in Event Viewer

After running the command, open Event Viewer to monitor what’s happening with LAPS:

```
Event Viewer  
 └► Applications and Services Logs  
     └► Microsoft  
         └► Windows  
             └► LAPS  
                 └► Operational
```

Look for **Event ID 1004**:

```
LAPS policy processing succeeded.
 
See https://go.microsoft.com/fwlink/?linkid=2220550 for more information.
```

This confirms the policy was applied successfully.

---

###  Verifying the LAPS Module

Ensure the Windows LAPS PowerShell module is available:

```powershell
Get-Module -ListAvailable LAPS
```

Example output:

```powershell
ModuleType Version    PreRelease Name                                PSEdition ExportedCommands
---------- -------    ---------- ----                                --------- ----------------
Script     1.0.0.0               LAPS                                Core,Desk {Find-LapsADExtendedRights, Get-LapsADP…
```

If no results appear, reinstall the Windows LAPS capability before retrying.

---

###  Exporting Diagnostic Logs

You can also collect diagnostic data for deeper troubleshooting:

```powershell
Get-LapsDiagnostics -OutputFolder "C:\LapsDiagFolder"
```

This exports detailed logs about policy evaluation, password rotation, and backup activity, which can help pinpoint configuration or permission issues.

