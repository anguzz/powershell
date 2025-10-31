# DNS Cache Flush with Logging

This PowerShell script captures and logs the system’s DNS cache before and after a flush operation.  


---

##  Script Overview

The script performs the following actions:
1. Creates a dedicated log directory (`C:\Logs\DnsCacheFlush\`) if it does not exist.  
2. Captures and saves the current DNS client cache to `DnsCacheBeforeFlush.txt`.  
3. Executes a system-level DNS cache flush using `ipconfig /flushdns`.  
4. Waits 2 seconds, then captures and saves the new DNS client cache to `DnsCacheAfterFlush.txt`.  
5. Logs all major operations and warnings to the console for traceability.

---

##  File Structure

| File | Description |
|------|--------------|
| `DnsCacheFlush.ps1` | Main PowerShell script |
| `C:\Logs\DnsCacheFlush\DnsCacheBeforeFlush.txt` | Log file capturing DNS cache entries before flush |
| `C:\Logs\DnsCacheFlush\DnsCacheAfterFlush.txt` | Log file capturing DNS cache entries after flush |

---

##  Usage

### **Run with Administrative Privileges**
To ensure access to system-level DNS cache, the script must be executed as Administrator.

```powershell
PowerShell.exe -ExecutionPolicy Bypass -File "C:\Scripts\DnsCacheFlush.ps1"


## Intune Notes
- **Context:** Run as **System** to clear the machine-level DNS cache.  
- **Impact:** Safe to run, no reboot required.  
- **Logs:** Saved under `C:\Logs\DnsCacheFlush\`.  

