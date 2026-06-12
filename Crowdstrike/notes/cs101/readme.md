# Falcon Platform Essentials

Notes based on on CrowdStrike Falcon 101 course  
<https://university.crowdstrike.com/learn/courses/468/falcon-101-falcon-platform-essentials>

# Falcon Sensor & Cloud Platform

## Falcon Sensor

* Captures endpoint security telemetry
* Performs **local analysis** for immediate protection
* Sends **enriched telemetry + alerts** to Falcon Cloud

## Falcon Cloud

Cloud backend for detection and response:

* Processes data using:
  * Machine learning
  * Behavioral analytics
  * Threat intelligence
* Detects and scores threats in real time
* Maintains up-to-date threat intelligence automatically

***

# Host Setup & Management

Central area to deploy and manage sensors.

## Key Functions

* **Host Groups** – Organize endpoints for policy/RBAC
* **Sensor Deployment** – Installers, tokens, updates
* **Health Monitoring** – Sensor status, coverage
* **Content Management** – Updates + data retention
* **Policy Enforcement** – Sensor behavior + settings

***

# Host Groups

Logical groupings of endpoints used for:

* Policy assignment (prevention, response, updates)
* RBAC scoping

## Best Practices

* Keep groups simple (OS, department, use case)
* Review membership regularly
* Avoid unnecessary overlaps (affects policy precedence)
* Prefer **dynamic groups** to automate assignment

***

# Endpoint Security

## How Detections Work

Falcon detects based on:

* Indicators of Attack (IOA)
* Machine learning
* Exploit detection
* Behavioral analysis

***

# Prevention Policies

Controls how endpoints are protected.

## Types

### System Default

* Built-in, auto-updated
* Cannot modify or delete
* Acts as fallback baseline

### Custom Policies

* Fully configurable
* Scoped to host groups
* Used for servers vs workstations, etc.

## Policy Behavior

* Inheritance via host group hierarchy
* Falls back to default if none assigned

## Policy Precedence

* Numeric priority (higher wins)
* Use high precedence for critical systems

***

# Indicators of Compromise (IOCs)

* Identify known malicious artifacts:
  * File hashes
  * IPs / domains
  * Registry keys / file paths
* Used to **detect or block known threats**

***

# Exclusions

Used to reduce false positives.

## Types

### ML File Path

* Skips ML analysis for specific paths
* Use for trusted internal apps

### ML Certificate

* Skips analysis for signed binaries
* Use for trusted vendors

### IOA Exclusions

* Suppress behavior-based detections
* Use for legit scripts/tools (e.g. PowerShell)

### Sensor Visibility Exclusions

* Stops telemetry collection (not detection)
* Used for:
  * Privacy/compliance
  * Performance issues

## Note

Overuse weakens security → review regularly

***

# Next-Gen SIEM & Identity Protection

## What It Does

Correlates signals from:

* Endpoints (Falcon)
* Identity (AD)
* Cloud (AWS, Azure)
* Logs (Syslog, CrowdStream)

## Identity Protection

### Capabilities

* **Monitor** – Identity activity + risk
* **Enforce** – Apply policies
* **Explore** – Threat hunting
* **Configure** – Integrations

### Common Detections

* Unusual logons (time/location)
* Brute force / password spraying
* Privilege escalation
* Lateral movement

***

# Cloud Security

Supports:

* AWS, Azure, GCP, OCI
* Kubernetes
* Hybrid environments

## Capabilities

* **Asset visibility** across cloud
* **Posture management** (misconfigs, IAM issues)
* **Vulnerability management** (CVEs, patch gaps)

***

# Real Time Response (RTR)

Remote shell for live response.

## Use Cases

* Investigate processes/network activity
* Kill processes, delete files
* Contain hosts
* Run scripts / collect artifacts

## Access Methods

* Host Management
* Host Search
* Detections
* Incidents (CrowdScore)

## Common Commands

```
ps         # running processes
netstat    # network connections
fileinfo   # file details
get        # download file
put        # upload file
kill       # terminate process
contain    # isolate host
runscript  # run script
```

## Syntax

```
command [subcommand] <args> -Flags
```

***

# Threat Intelligence & Charlotte AI

## Threat Intelligence

* Provides adversary context:
  * Tactics
  * Targets
  * Tools
* Enriches detections with real-world intel

## Charlotte AI

* Natural language assistant
* Query detections, hosts, users
* Speeds up investigations

## PromptBooks

* Pre-built investigation workflows
* Standardize analyst actions
* Improve consistency

***

# Key Takeaways

* Falcon = **sensor (endpoint) + cloud (analytics)**
* Policies + host groups drive control
* Exclusions must be used carefully
* NG SIEM unifies endpoint, identity, and cloud signals
* RTR enables fast incident response
* Threat intel + AI improves investigation speed and context

