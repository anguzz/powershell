# Tanium – Dell SupportAssist Removal

This package outlines scripts and Tanium workflows used to remove **Dell SupportAssist** from endpoints. 

SupportAssist was consuming excessive disk space due to backup activity and frequently appeared in vulnerability scan findings so it was decided to remove the bloatware. 



## Tanium Queries

### Identify devices with SupportAssist installed

```sql
Get Computer Name from all entities
with Installed Application Exists[Dell SupportAssist] equals True
```

### Get total count of installations

```sql
Get Installed Application Exists[Dell SupportAssist] equals True
from all entities
with Installed Application Exists[Dell SupportAssist] equals True
```

---

## Uninstall Command (Tanium Action)

```sql
cmd.exe /c %windir%\SysNative\WindowsPowerShell\v1.0\PowerShell.exe `
  -NoProfile -ExecutionPolicy Bypass -File uninstall.ps1
```

---

## Verification Query

```
Installed Applications does not contain Dell SupportAssist
```

> Note: Deployment may require multiple passes due to Dell SupportAssist services, remediation agents, or installer state.

---

## Scripts & Resources

### 1) uninstall.ps1

**Source:**
[https://github.com/FlyingTom03/Dell-Support-Uninstall-Delete/blob/main/Uninstall-Delete-Powershell-Script](https://github.com/FlyingTom03/Dell-Support-Uninstall-Delete/blob/main/Uninstall-Delete-Powershell-Script)

**Notes:**

* Worked successfully on the majority of endpoints
* Required multiple re-runs on some systems due to service state or installer behavior
* Modified to:

  * Stop SupportAssist-related processes prior to uninstall
  * Continue execution silently when errors occur

---

### 2) ninja-one-uninstaller.ps1

**Source:**
[https://www.ninjaone.com/script-hub/remove-dell-supportassist-with-powershell/](https://www.ninjaone.com/script-hub/remove-dell-supportassist-with-powershell/)

**Notes:**

* Higher success rate on remaining endpoints
* More structured uninstall logic
* Better handling of MSI-based SupportAssist installs


---

## Summary

* Dell SupportAssist removal is **state-dependent** and may require **multiple execution cycles**
* Combining multiple scripts improved overall removal success
* Scripts were executed via Tanium with targeted verification to ensure eventual convergence

