
# Falcon 102 

## User Setup (RBAC)

Path:

```
Host setup & management → Falcon users → User management
```

Recommended baseline:

* 2 × Falcon Admins (redundancy)
* 1 × Real Time Response role
* Custom roles (least privilege)

***

## Sensor Deployment Strategies

### 1. CrowdStrike Only

* Replace existing AV completely

**Pros**

* Simple management
* Lower cost

**Cons**

* Higher risk during transition

***

### 2. Short-Term Coexistence (Recommended)

* Run Falcon alongside existing AV temporarily
* Tune → then remove old AV

**Pros**

* Safer rollout
* Allows tuning/exclusions

**Cons**

* Temporary complexity
* Possible performance impact

***

### 3. Long-Term Coexistence (Not recommended)

* Keep multiple AVs permanently

**Cons**

* Alert duplication
* Cost + complexity

***

## Network Requirements

* Uses **TLS over port 443**
* Requires access to CrowdStrike cloud endpoints

⚠️ If using:

* SSL inspection / TLS decryption / DPI

→ Must **bypass CrowdStrike traffic**

Reason:

* Falcon uses **certificate pinning**
* Inspection will break sensor comms / installs

***

## Reduced Functionality Mode (RFM)

### What it is

* Sensor fallback mode when it **can’t reach cloud**
* Keeps **basic protection**
* Loses:
  * real-time updates
  * telemetry / visibility

***

### Common causes

* Network connectivity issues
* Unsupported kernels (Linux)
* Early patching before Falcon certification window
* macOS missing Full Disk Access (FDA)

***

### Recovery

* Restore network connectivity
* Update OS/kernel to supported version
* On macOS → enable **Full Disk Access**

***

### Monitoring

Path:

```
Host setup & management → Sensor health
```

***

## Notifications

Path:

```
Support & resources → General settings → Notifications
```

Types:

* Detection & Incident emails
* Fusion SOAR notifications
* Scheduled search alerts (requires Investigate)

***

## Fusion SOAR

Path:

```
Fusion SOAR → Workflows
```

Use for:

* Custom alert routing
* Automation (who gets notified, when, and how)

***

## Prevention Policies (Phased Approach)

### Phase 1 – Monitor Only

* Minimal enforcement
* Coexists with AV
* Short-term only

***

### Phase 2 – Moderate Protection

* Gradually increase enforcement

***

### Phase 3 – Full Protection

* Full blocking + detection

***

### Important

* Policies use **precedence order**
* Highest precedence policy wins

***

## Sensor Update Policies

Path:

```
Host setup & management → Sensor update policies
```

### Key Concepts

* **Version control** – lock versions per group
* **Testing group** – validate before broad rollout
* **Auto N-1 (recommended)** – second newest version
* **Auto N-2** – more conservative
* **Auto Latest** – fastest updates (higher risk)

***

### Best Practice

* Update monthly
* Avoid going beyond **N-2**

***

### Security Features

* **Uninstall protection**
  * Requires token
  * Prevents tampering

* **Bulk maintenance mode**
  * One token for many hosts

***

## Deployment Approach

### Phases

1. Pre-production testing
2. Pilot
3. Iterative rollout
4. Full deployment

***

### Methods

**Manual**

* Small environments / testing

**Automated**

* SCCM, Intune, Jamf, etc.
* Required for scale

***

⚠️ Do NOT reboot during installation

***

## Troubleshooting Sensors

### Not registering

* Check CID
* Check network
* Review logs

### Install failure

* Run as admin
* Validate OS compatibility
* Re-download installer

### App conflicts

* Test beforehand
* Add exclusions

### Rollback

* Uninstall sensor
* restore previous state

***

## Host Groups

### Purpose

* Apply:
  * policies
  * updates
  * exclusions
  * bulk actions

***

### Types

**Dynamic**

* Auto membership (attributes)
* Near real-time updates

**Static**

* Manual
* Good for testing

***

### Notes

* Max \~1000 hosts per batch operation
* OS version can be used as a dynamic rule

***

## Policy Precedence

Flow:

1. Host in multiple groups
2. Each group has policies
3. Precedence evaluated
4. Highest wins

***

Verify:

* Group level → assigned policies
* Host level → applied policies

***

## False Positives & Exclusions

### Key Concepts

* **False Positive** → benign flagged as malicious
* **Alert fatigue** → too many alerts = risk
* **Allowlisting** → reduce noise

***

### Detection Types

* **IOC** → known bad
* **IOA** → behavior-based
* **ML** → file property-based

👉 Difference:

* ML = file characteristics
* IOA = behavior patterns

***

## Exclusion Types

### Hash-based

* Exact file only
* Low risk

***

### File path-based

* Folder/app level
* Medium risk

***

### IOA exclusions

* Behavior suppression
* Medium–high risk

***

### Sensor Visibility Exclusion (SVE)

* Disables telemetry/detections

⚠️ Very high risk — last resort only

***

## Creating Exclusions

### Hash

```
Endpoint Security → IOC Management → Add hash
```

***

### File path

```
Endpoint Security → Exclusions → ML exclusion
```

***

### IOA

* From detection → create IOA exclusion
* Uses:
  * process name
  * command line
  * path

***

## macOS Sensor Requirements

### Big Sur (11+)

* System extension
* Network filter
* Full Disk Access

***

### Catalina (10.15)

* Kernel extension
* Full Disk Access

***

### Without MDM

* Manual approval required per device

***

## OAuth2 for Falcon APIs

### Components

* **Client ID** → identifier
* **Client Secret** → credential
* **Access Token** → short-lived (\~30 min)

***

### Use cases

* Automation
* SIEM/SOAR integration
* Reporting
* Incident response

***

## Support Portal

Path:

* Click top-right **chat/message icon**
* Select **Support Portal**


