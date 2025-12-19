
# Tanium Threat Hunting & Detection – Condensed Notes

## Core Data Sources

### **Recorder**

* Kernel-level telemetry capture on endpoints
* Stores **historical activity** in local recorder DB
* Used by **Trace sensors** for lookbacks
* Captured telemetry (OS-dependent):

  * Process execution
  * File activity
  * Registry changes (Windows)
  * Network connections
  * Image/driver loads
  * User authentication


### **Index**

* Local endpoint file metadata database
* Enables **fast file-at-rest searches** with low performance impact
* Indexed data:

  * File path, size, timestamps
  * Hashes (MD5, SHA1, SHA256)
  * Permissions
  * Magic number (file signature)
* Prevents expensive recursive disk scans



## Detection Engineering

### Threat Intelligence Types

| Type           | What It Does               | Notes                              |
| -------------- | -------------------------- | ---------------------------------- |
| **Signals**    | Real-time event matching   | Continuous evaluation via Recorder |
| **IOCs**       | Match known bad indicators | Domains, IPs, hashes               |
| **YARA**       | Pattern-based detection    | Files or live memory               |
| **Reputation** | Hash reputation lookups    | 3rd-party intel sources            |

* **Signals** should be *atomic* (1 technique per signal)

* Tanium is **not a traditional EDR**:

  * Detection + visibility first
  * Response via **actions, playbooks, quarantine**
* Intel matches can trigger:

  * Kill process
  * Delete file
  * Quarantine endpoint
  * SOAR integrations


## YARA (Important Constraints)

* Scan locations:

  * **Live Files** (running processes only)
  * **Memory** (Windows & macOS)
  * **Paths** (recursive, max depth 32)
* Performance-heavy → **tight scoping required**
* Best used for:

  * Malware families
  * Obfuscated payloads
  * Pattern-based threats



## Alert Tuning & Safeguards

### Throttling

* **Endpoint-side throttling**: excessive alerts from one intel
* **Server-side throttling**: excessive alerts across many endpoints
* Prevents alert storms

### Intel Safeguards

* Intel can be **auto-disabled** if noisy
* Tuning options:

  * Signals → edit logic or suppress
  * IOCs → update or retire
  * YARA → adjust scope or rule
  * Reputation → adjust verdict thresholds



## SOC Alert Review (What to Look At)

### Alert Sections

* **Metadata**: time, endpoint, source
* **Event Details**: what triggered
* **Responsible Process**:

  * Command line
  * Parent/child chain
  * Hashes
* **Intel**:

  * Signal / IOC / YARA
  * MITRE technique mapping
* **Impact**:

  * Lateral movement potential



## Incident Response

### Live Investigation

* **Direct Connect**: real-time endpoint access
* **File Browser**: browse/download/delete files
* **Live Response**:

  * Collect forensic artifacts
  * Memory analysis
  * Offline evidence gathering


### Evidence Collection

* Use Recorder DB for **historical reconstruction**
* Use Index for **environment-wide file checks**
* Stream selected telemetry to SIEM (not all data)



## Proactive Threat Hunting Workflow

1. **Start with a hypothesis**

   * Unauthorized software
   * Suspicious outbound connections
2. **Select sensors**

   * Installed Applications
   * Local Accounts
   * Network Connections
3. **Correlate**

   * Process → IP → file → hash
4. **Validate**

   * Context Analyzer: *Is this normal here?*
5. **Promote**

   * Convert findings into Signals / Intel


## Architecture (Why Tanium Scales)

* Linear chain topology (not hub-and-spoke)
* Endpoints relay data peer-to-peer
* Minimizes WAN usage
* High resilience at scale



## Key Takeaways

* Recorder = **time machine**
* Index = **file intelligence**
* Signals = **real-time detection**
* YARA = **powerful but expensive**
* Always **scope narrowly**
* Tune intel before broad deployment
