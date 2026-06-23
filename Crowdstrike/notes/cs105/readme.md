# Falcon 105 – Sensor Installation, Configuration, and Troubleshooting

## Prerequisites (Windows)

Ensure these **services are installed and running**:

* LMHosts
* Network Store Interface (NSI)
* Windows Base Filtering Engine (BFE)
* Windows Power Service

**Notes:**

* LMHosts may be disabled if **TCP/IP NetBIOS Helper** is disabled.
* If using a proxy:
  * Ensure **WinHTTP AutoProxy** is available.
  * If using WPAD → **DHCP Client must be running**

***

## Antivirus Requirements

* **Workstations**: Defender auto-disabled when CrowdStrike installs
* **Servers**: Defender must be manually disabled

To use Falcon NGAV:

```powershell
Set-MpPreference -DisableRealtimeMonitoring $true
```

***

## Network Requirements

### Protocols

* Requires **TLS 1.2**
* SSL / older TLS versions are **not supported**

### CrowdStrike Cloud Endpoints

| Cloud    | Address                                                              |
| -------- | -------------------------------------------------------------------- |
| US-1     | ts01-b.cloudsink.net / lfodown01-b.cloudsink.net                     |
| US-2     | ts01-gyr-maverick.cloudsink.net                                      |
| US-GOV-1 | ts01-laggar-gcw\.cloudsink.net / lfodown01-laggar-gcw\.cloudsink.net |
| US-GOV-2 | ts01-us-gov-2.cloudsink.crowdstrike.mil                              |
| EU       | ts01-lanner-lion.cloudsink.net                                       |

***

## TLS / Inspection Considerations

Falcon uses **certificate pinning**.

 Must disable:

* Deep Packet Inspection
* HTTPS / TLS / SSL interception

Otherwise → sensor communication breaks.

***

## Policy Behavior

### Default Behavior

* Sensors inherit the **default prevention policy**
* Override via **Host Groups**

### Policy Precedence

* Hosts can belong to multiple groups
* **Precedence determines which policy applies**

Notes:

* Prevention policies → precedence-based
* Sensor update → first-match (older = higher precedence by default)
* Content updates → explicitly ordered (API / console)

***

## Rapid Response

* Uses **allow/block lists**
* Handles:
  * False positives
  * False negatives
* Applies to IOA and ML detections

***

# Windows Installation

## Manual Install

1. Go to:
   ```
   Host Setup & Management > Deploy > Sensor Downloads
   ```
2. Copy **CCID**
3. Run installer with CCID

## Verify Install

```powershell
sc query csagent
```

***

## Silent Install

```bash
<installer>.exe /install /quiet /norestart CID=<CCID>
```

### With Tags

```bash
<installer>.exe /install /norestart CID=<CCID> GROUPING_TAGS="Washington/DC_USA,Production"
```

* Tags are **case-sensitive**
* Max length = **256 chars**

***

# Uninstall

## Control Panel

* Programs → CrowdStrike Windows Sensor → Uninstall
* Requires **maintenance token** if enabled

## CLI

```bash
CsUninstallTool.exe /quiet
```

***

## Validate Removal

* Program gone from list
* Folder removed:
  ```
  C:\Windows\System32\drivers\CrowdStrike
  ```
* Registry key removed:
  ```
  HKLM\System\Crowdstrike
  ```

***

## Uninstall Protection Scenarios

### Case 1 – Sensor Online

* Move host to policy with protection disabled
* Then uninstall

### Case 2 – Offline + Protection Enabled

* Get **single-use maintenance token**
* Run:

```bash
CsUninstallTool.exe MAINTENANCE_TOKEN=<token> /quiet
```

### Case 3 – Offline + Bulk Mode

* Get **bulk token**
* Use same uninstall command

***

# Linux Deployment Modes

### Standard Host

* Installed directly on host

### Containers (Kubernetes)

* Deploy as **DaemonSet**

### Restricted Environments (e.g., Fargate)

* Deploy as **sidecar container**

### Notes

```bash
uname -r
```

* Unsupported kernel → runs in **Reduced Functionality Mode (RFM)**

***

# macOS

* Requires **elevated privileges** for install

***

# VM Template Deployment

## Key Concepts

* Use **NO\_START=1** when installing on templates
* Prevents duplicate **Agent IDs (AID)**

***

## Template Install

```bash
WindowsSensor.exe /install CID=<CID> NO_START=1
```

### With Token

```bash
WindowsSensor.exe /install CID=<CID> NO_START=1 ProvToken=<TOKEN>
```

***

## Validate Before Template

```powershell
sc query CSFalconService
```

Check files:

```
C:\Program Files\CrowdStrike\WindowsSensor\
```

***

## Template Conversion

 Do NOT reboot before converting

Steps:

1. Shutdown
2. Convert to template
3. Deploy VMs
4. Each VM gets unique AID

***

## Fix Duplicate AID

Delete:

```
HKEY_LOCAL_MACHINE\SYSTEM\CrowdStrike\...\Default\AG
```

Then reboot.

***

# Install Failures / Troubleshooting

## Issue 1 – Sensor Installed but Not Running

Check:

* Required services:
  * LMHosts
  * BFE
  * DNS Client
  * DHCP Client (if WPAD)
* WinHTTP AutoProxy (if proxy used)

***

## Issue 2 – No Cloud Connectivity

Check:

* Internet access
* Proxy config
* Firewall rules (allow Falcon traffic)
* LMHosts enabled
* Trusted CrowdStrike certificate authority

***

## Install Behavior Note

* If connection fails during install:
  * Retries after **10 minutes**
  * Fails again → **sensor uninstalls automatically**
