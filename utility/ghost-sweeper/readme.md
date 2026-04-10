# GhostSweeper – Employee Monitoring Software Detection Script

## Overview

GhostSweeper is a custom PowerShell-based privacy auditor designed to detect both "visible" productivity trackers and "invisible" stealth or ghost monitoring agents on Windows systems. Unlike basic inventory scripts, it specifically hunts for cloaked processes and obfuscated directory structures used by modern 2026-era monitoring solutions.


## Example
<img width="800" height="398" alt="image" src="https://github.com/user-attachments/assets/e76c7a09-9715-4d5a-beec-91378ef8db7e" />

---

## Features

### 1. Vendor Signature Detection (2026 Updated)

Includes deep-scan signatures for:

* **ActivTrak** (including `scthost` stealth mode)
* **Teramind** (including GUID-hidden silent agents)
* **Monitask** (including `deskcap` invisible capture)
* **Veriato / Spector / InterGuard** (including `dgagent` system workers)
* **SentryPC** (including `spc` cloaked folders)
* **Insightful, Hubstaff, Time Doctor, and more.**

### 2. Stealth & Obfuscation Detection (New)

The script specifically targets "Silent Mode" installations by scanning:

* **Mimicry Processes:** Identifying non-system files posing as Windows Hosts (e.g., `scthost.exe`).
* **Hidden System Directories:** Scanning `SysWOW64` and `System32` for non-standard vendor binaries.
* **GUID-Masked Folders:** Detecting trackers that hide inside `ProgramData` using randomized Registry-style strings.

### 3. Heuristic Keyword Analysis

Searches for unbranded or custom tools using keywords like `keylog`, `screenrec`, `surveillance`, and `useractivity` within active memory and persistence triggers.

---

## How Tracking Software Hides

Modern employee monitoring has evolved to bypass the "Add/Remove Programs" list. Here is how **GhostSweeper** catches them:

### A. Process Mimicry

Many tools rename their executables to sound like critical Windows components.

* **Example:** ActivTrak often installs as `scthost.exe`. To a casual user in Task Manager, this looks nearly identical to the legitimate Windows process `svchost.exe`.
* **The Counter:** GhostSweeper checks the file metadata and path. If "host" software is running from a non-standard directory or lacks a Microsoft digital signature, it is flagged.

### B. The "Invisible" Install (Silent Mode)

High-end trackers like Teramind or Veriato offer "Silent" versions. These do not create desktop icons, start menu entries, or tray icons.

* **Example:** They often hide their files in `C:\ProgramData\{Random-GUID}` or `C:\Windows\temp`.
* **The Counter:** The script scans these specific "blind spot" directories for known file-hash patterns and signature behaviors.

### C. Registry & WMI Persistence

Instead of appearing in the "Startup" tab of Task Manager, stealth trackers often use:

* **Registry Run Keys:** Hiding in the `Wow6432Node` (32-bit compatibility layer) where most users don't look.
* **Services:** Running as a "Background Service" set to `Automatic`, making them start before a user even logs in.

---

## Data Sources Queried

| Source | Purpose |
| --- | --- |
| **System32 / SysWOW64** | Hunting for mimicry binaries (like `scthost.exe`) |
| **ProgramData / LocalAppData** | Checking for GUID-masked folders and local databases |
| **Uninstall Registry (HKLM/HKCU)** | Detecting "Visible" productivity trackers |
| **Get-Process / Get-Service** | Identifying active stealth workers and background listeners |
| **Registry Run Keys** | Analyzing how the software survives a reboot |

---

## Requirements

* **Windows 10 / 11**
* **PowerShell 5.1+**
* **Administrative Privileges (Required):** Essential to scan `System32` and `HKLM` registry hives where stealth agents reside.

---

## Usage

### Run as Administrator

To ensure the script can see "Cloaked" files in system directories:

1. Right-click PowerShell -> **Run as Administrator**.
2. Run the script:
```powershell
.\sweep.ps1

```



---

## Detection Types Explained

| Type | Meaning |
| --- | --- |
| **Stealth Process** | A process mimicking system files or running from a hidden path. |
| **Cloaked Folder** | A directory used by "Silent" agents to hide logs and screenshots. |
| **System Service** | A background agent running with System-level permissions. |
| **Startup Entry** | A trigger that re-launches the tracker upon every boot. |

---



## References & Inspiration
- https://github.com/AssoEchap/stalkerware-indicators


## Next Steps
- Incorporate relevant stalkerware/watchware indicators from the AssoEchap IOC repository and expand GhostSweeper’s Windows focused signature set.
- Review additional public IOC and security research repositories to further enrich process, service, path, certificate, and network indicator coverage.
- Expand detection coverage to include scheduled tasks, WMI persistence, startup folders, and network indicators (DNS/cache/hosts).


## Security and Ethical Notice

This tool is for **transparency and auditing**. Users are encouraged to use this script to understand what is running on their hardware. Be aware that disabling or tampering with monitoring software on company-owned assets may lead to disciplinary action.



