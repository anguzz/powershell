# AD Group Cleanup Hygiene Dashboard

---

## Overview

This project provides a structured pipeline to analyze, validate, and clean up Active Directory (AD) groups using:

- Active Directory data (current state)
- A Streamlit dashboard for visualization and decision-making

The goal is to identify stale, unused, or low-value groups and enable safe, repeatable cleanup workflows.

> **Note:** This solution is intentionally built to work with AD data only for maximum portability.  
> It can be extended with additional telemetry sources (e.g., Splunk, CrowdStrike, Sentinel, or other SIEM platforms) to improve confidence in cleanup decisions.  
>
> In practice, you can ingest logs and telemetry from those platforms (such as authentication events or group membership changes) and incorporate them into the dataset to strengthen scoring and provide better signals for cleanup decisions.

---

## Architecture / Pipeline

The process is intentionally simple and portable:

### 01 — Collect AD Group Inventory

Run:

```powershell
.\01-Get-ADGroupInventory.ps1
````

This generates:

```
AD-Groups-Inventory.csv
```

This dataset represents the current state of all AD groups.

***

### 02 — Launch Dashboard

Run:

```bash
python -m streamlit run 02-ADGroupCleanupDashboard.py --server.address 127.0.0.1 --server.port 8501
```

***

### 03 — Analyze and Select Candidates (Manual Review)

Use the dashboard to:

* Filter groups
* Identify stale or empty groups
* Review ownership and metadata gaps
* Select cleanup candidates

***

## Candidate Selection (Manual Workflow)

### 1. Filter groups

Focus on:

* `IsEmpty = True`
* High `StaleDays` (derived from `whenChanged`)
* Missing `ManagedBy`
* Missing `Description`

***

### 2. Refine dataset

Select a manageable batch:

* Typically 50–100 groups per cycle

Prioritize:

* Empty groups
* Older groups
* Groups without ownership or metadata

***

### 3. Export results

Use the **Download filtered CSV** feature in the dashboard. Call the csv cleanup-groups.csv and remove any additional rows you want to keep.


***

### 4. Create cleanup dataset

Save selected rows into:

```
cleanup-groups.csv
```

**Important:**

* Do not modify `ObjectGUID`
* `ObjectGUID` is the authoritative identifier used for deletion

***

## Deletion Pipeline (GUID-Based Targeting)

### Overview

This phase validates and executes deletions using ObjectGUID-based targeting to avoid issues caused by:

* Renamed groups
* Moved objects (DN changes)
* Duplicate names

***

### 04 — Validate and Delete Groups

Run:

```powershell
.\03-Invoke-ADGroupCleanup.ps1
```

***

### Execution Modes

Runs in what if by default, uncomment when ready.

### Validation Behavior (Dry Run)

* Validates each `ObjectGUID`
* Resolves to live AD objects
* Performs no deletion
* Outputs:

```
groups-deleted.csv
```

***

### Validation Output Includes

* Timestamp
* Execution mode
* GUID validation result
* AD lookup result
* Planned action
* Resolved attributes:
  * Name
  * SamAccountName
  * DistinguishedName
  * ObjectGUID / SID
  * GroupCategory / Scope
  * whenCreated / whenChanged

***

### Deletion Execution

After approval:

* Enable execution mode in script
* Run again to perform deletion

***

### Audit & Tracking

For each cycle:

* Store:
  * Input dataset (`cleanup-groups.csv`)
  * Output log (`groups-deleted.csv`)

* Attach to:
  * Change ticket
  * Shared repository

**Goal:**

* Full audit trail
* Reproducibility
* Operational transparency

***

## Data Model

### Active Directory Data (State-Based)

Provides a snapshot of group state:

#### Identity

* Name
* SamAccountName
* DistinguishedName
* ObjectGUID / SID

#### Type

* Security vs Distribution
* Group scope

#### Metadata

* Description
* ManagedBy

#### Timestamps

* whenCreated
* whenChanged

#### Membership

* MemberCount
* IsEmpty

#### Mail

* Mail-enabled status

***

## Limitations of AD-Only Analysis

AD data is static and does not reflect real-world usage.

This means:

* A group may appear unused but still be critical
* No visibility into:
  * Authentication usage
  * Application dependencies
  * Access patterns

***

## Optional Enhancement: Behavioral Data

This solution can be extended with:

* SIEM platforms (Splunk, Microsoft Sentinel)
* Windows Security logs
* Entra ID audit logs

These sources can provide:

* Membership activity (adds/removals)
* Usage patterns over time
* Administrative actions

This adds behavioral context to improve decision-making.

***

## Cleanup Strategy (State-Based)

### Priority Order

#### 1. Zero-member groups

* Safest to delete
* Highest confidence

#### 2. Old + unchanged groups

* Likely stale

#### 3. Groups missing metadata

* Require review

#### 4. Active groups

* Do not delete
* Require documentation

***

## Batch Cleanup Process

### Workflow

* Select 50–100 groups per cycle
* Review using dashboard
* Validate candidates
* Present for approval
* Execute deletion

***

## Dashboard Setup

### Install dependencies

```bash
pip install pandas numpy streamlit plotly
```

***

### Run dashboard

```bash
python -m streamlit run 02-ADGroupCleanupDashboard.py
```

***

## Design Philosophy

This project separates:

* **State-based data (AD)** — always available
* **Behavior-based data (optional)** — environment-specific

This allows the solution to be:

* Portable
* Easy to deploy
* Extensible
