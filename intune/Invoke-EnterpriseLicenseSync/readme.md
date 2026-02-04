## README: Windows Activation Fix

### **Purpose**

Fixes "Not Activated" watermarks and sync errors on Intune-joined Windows 11 Enterprise machines.

### **What it does**

* **Refreshes PRT** Refreshes Entra ID Primary Refresh Token (usually works better in user context but doesn't hurt to run under system)
* **Restarts Service:** Forces the Software Protection Service (`sppsvc`) to run.
* **Triggers Activation:** Forces an immediate license check-in via `slmgr`.
* **Hides Watermark:** Disables activation UI notifications in the registry (fixes visual bugs).

### **Intune Deployment**

* **Run as logged-on user:** No (Run as SYSTEM).
* **64-bit PowerShell:** Yes.
* **Assignment:** Target devices showing "Not Active" despite valid E3/E5 licenses.

### **Notes**

* **Restart Required:** The watermark usually persists until the next reboot or Explorer restart.
* **Persistence:** If the watermark returns, verify the user has a **Microsoft 365 E3/E5** license assigned.
