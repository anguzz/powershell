
# Setup azure VM monitoring + notes
- Goal: we want to make dashboards with azure monitoring that monitor azure vm processes, cpu util, etc.


##  Azure Monitoring Services
| Layer                            | What It Does                                                                        | Example in Your Project                                    |
| -------------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| **Azure Monitor**                | The umbrella service that collects, analyzes, and acts on telemetry from resources. | The foundation of all dashboards/alerts.                   |
| **Log Analytics Workspace**      | Central store for logs and performance data.                                        | Where VM metrics, event logs, and custom data are sent.    |
| **Azure Metrics**                | Lightweight performance counters (CPU, memory, etc.) collected at 1-min intervals.  | Used for CPU/disk utilization charts.                      |
| **Azure Alerts**                 | Rules that trigger actions (emails, SMS, Logic App) when thresholds are hit.        | “If CPU > 90% for 10 mins, send email.”                    |
| **Azure Dashboards / Workbooks** | Visualization layer.                                                                | Graphs and tiles showing resource health, CPU trends, etc. |
| **Azure Monitor Agent (AMA)**    | The modern data collection agent installed on VMs.                                  | Needed to send data (event logs, performance metrics).     |
| **Action Groups**                | Define *who* or *what* to notify (email, Teams, SMS, webhook, etc.).                | Send alerts to IT             |


## Azure resource hierachy
- Subscription -> resource group -> Resource (vm/storage/etc)
- We setup scope tied to each of these levels (per sub, per resource)

## VM monitoring pipeline
- vm sends metrics -> goes to analytics workspace ->alerts/dashboards visualize it
- without the ama agent no metrics


## KQL 
Kusto Query Language (KQL) is used to log analystics in query logs
- like sql for monitoring dashboards and workbooks.

```sql
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), Computer
```


# Setup Monitoring on VMs.
My notes/process on setting up azure monitoring on vms.

*Optional: go to azure portal: search vms and skip to step 3*

 1) Go to  https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/virtualMachines

 2) Go to `monitor -> virtual machines -> configure insights`
 - Here we can see VMS that are `not monitored` and their corresponding resource group

3) Go to on one of the VMs

4) Under the `virtual machines | Insights page`  configure `enhanced monitoring`.

Here you should have two metric types that report differently. Add the one you need or both, both install the AMA monitoring agent.
- `OpenTelemetry metrics` go to `Azure monitor workspaces`  AMA sends data to a Log Analytics workspace
- `Log-based metrics` go to `Log Analytics workspace`: AMA additionally streams a subset of telemetry to the Azure Monitor Metrics backend
- Either can be added to a dashboard/workgroup once its setup

### Important note:
Going to a VMs insights page will automatically generate azure monitoring and create a default data collection rule following `MSVMI-region-vm-name` format.

It will actually now show up as a monitored vm under https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/virtualMachines and if we click under our performance tab.

I found some more info on this at https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-enable?tabs=portal#prerequisites, if no agents are onboarded this area will not populate.


### Dashboards vs workbooks

| Tool                | Use Case                                        | Description                                                       |
| ------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| **Azure Dashboard** | Quick visual overview across multiple resources | Tiles you can pin from anywhere in the portal                     |
| **Azure Workbook**  | Rich, interactive visualization & queries       | Uses KQL (Log Analytics queries) for charts, filters, time ranges |

I personally setup dashboards for my use case since since I just want basic info.

### Github community kql queries
- https://github.com/microsoft/AzureMonitorCommunity


### Note: Export queries easily

1) Go to Log analytics workspace 
2) Go to logs
3) Queries hub opens automatically or Click New query
5) Choose a query
6) Hit run
7) Save as function to seee the code block, copy paste it and export it for re-use
*optionally, Pin to a custom dashboard*



#  VM Uptime Alert example
Overview/notes on setting up Azure alerts 

This can be done under the `Monitor | Alerts` tab in the [Azure Portal](https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/alertsV2).

## Overview

| Concept | Purpose | Example |
| -------- | -------- | -------- |
| **Alert Rule** | Watches for a metric condition | “If uptime > 30 days, trigger alert.” |
| **Scope** | Defines monitored resources | “All VMs in rg-vms, etc .” |
| **Action Group** | Defines who gets notified | “Email sysadmins + SMS on-call.” |

---

## Setup Steps

### 1. Create Action Group
Defines *who* and *how* to notify.

- Add emails, SMS, webhooks, or Teams connectors  
- Reuse across alerts (e.g., `ag-system-alerts`, `ag-network-alerts` etc)

---

### 2. Create Alert Rule


Defines *what* condition triggers.

- **Metric:** `system/uptime`
- **Operator:** Greater than  
- **Threshold:** `2592000` (30 days)  
- **Frequency:** 1 min  
- **Lookback:** 5 min  
- **Severity:** Can choose from 1-5 here  
- **Action group:** `ag-sysadmin-alerts`

> *Uptime uses seconds (Prometheus/OpenTelemetry standard).*

---

### 3. Set Scope

- **Add VM**  - Add a VM 
- **Resource Group** – or add RG of vms
- **Subscription** – Choose subscription

---

### 4. Save & Deploy

- Review → Create  
- Azure Monitor starts evaluating immediately  
- Alert fires once uptime crosses 30 days

---

### 5. Receive Alerts

- Email/SMS/Webhook sent  
- Links to Azure Monitor  
- Auto-resolves when cleared  

---

## Optional Use Cases

| Scenario | Example |
| -------- | -------- |
| Detect reboot | `system/uptime < 300` |
| Detect agent offline | KQL: `Heartbeat` table |
| Detect VM stopped | Activity log: `Power Off Virtual Machine` |
| Escalate alerts | Add webhooks |


---

## Azure Alerts & Suppression (High Level)

1. **Create an Action Group**
   Defines who receives notifications (email, SMS, webhook, chat).

2. **Create an Alert Rule**
   Defines what triggers the alert (metric, threshold, frequency) and which action group is used.

3. **Set Scope**
   Apply the alert to VMs, a resource group, or a subscription.

4. **Alert Fires**
   When the condition is met, Azure Monitor triggers the alert and sends notifications.

---


# Azure Monitor – Tiered VM Availability Alerts with Maintenance Suppression

## 1. Overview
This design reduces **alert fatigue during scheduled maintenance** while ensuring prolonged VM outages are **never missed**.  
It uses two availability alerts with different evaluation windows and a **targeted alert processing (suppression) rule** that silences only expected reboot noise.

---

## 2. Alert Rules

### Alert Rule A: VM Availability – Short Duration

**Purpose:**  
Detects short VM outages (e.g., reboots during patching). These alerts are expected during maintenance and are suppressed.

#### Configuration
| Setting | Value |
|------|------|
| **Signal** | `VmAvailabilityMetric` |
| **Operator** | Less than |
| **Aggregation type** | Average |
| **Threshold** | `< 1` |
| **Lookback period** | 5 minutes |
| **Evaluation frequency** | 1 minute |
| **Severity** | Informational |
| **Auto-resolve** | Enabled |

#### Behavior
- Triggers quickly when a VM becomes unavailable
- Intended to catch platform-level outages or deallocations
- Suppressed during maintenance windows to avoid noise

---

### Alert Rule B: VM Availability – Prolonged Outage

**Purpose:**  
Acts as a safety net to catch VMs that fail to recover after maintenance.

#### Configuration
| Setting | Value |
|------|------|
| **Signal** | `VmAvailabilityMetric` |
| **Operator** | Less than |
| **Aggregation type** | Average |
| **Threshold** | `= 0` |
| **Lookback period** | 1 hour |
| **Evaluation frequency** | 5 minutes |
| **Severity** | Error |
| **Auto-resolve** | Enabled |

#### Behavior
- Fires only if a VM remains unavailable for **60 continuous minutes**
- Bypasses maintenance suppression
- Designed to catch stuck patching, failed boots, or hung systems

---

## 3. Maintenance Suppression Rule

### Scheduled Maintenance – Alert Suppression

**Purpose:**  
Suppress notifications only for short-duration availability alerts during known maintenance windows.

#### Scope
- Subscription-level or resource-group–level scope
- Targets infrastructure virtual machines

#### Rule Type
- **Suppress notifications**

#### Schedule
| Setting | Value |
|------|------|
| **Recurrence** | Weekly |
| **Days** | Saturday → Sunday |
| **Start Time** | 7:00 PM (Local / PST) |
| **End Time** | 2:00 AM (Next day) |
| **Timezone** | Local maintenance timezone |

#### Filter Configuration
| Setting | Value |
|------|------|
| **Filter type** | Alert rule name |
| **Operator** | Equals |
| **Value** | VM Availability – Short Duration |

#### Result
- Only short-duration availability alerts are suppressed
- Long-duration outage alerts remain active and notify immediately
- Prevents maintenance from masking real failures

---

## 4. Notification & Routing

### Central Action Group

All alert rules route through a single centralized notification mechanism.

#### Configuration
| Setting | Value |
|------|------|
| **Delivery methods** | Email |
| **Targets** | Operations distribution list, ticketing system |
| **Region** | Global |

#### Alert Flow
| Alert Type | During Maintenance | Outside Maintenance |
|---------|------------------|------------------|
| Short Duration | Suppressed | Notifies |
| Prolonged Outage | Not Suppressed | Notifies |

#### Extensibility
- SMS, push notifications, or on-call escalation can be added for prolonged outage alerts
- Different action groups can be attached per severity if needed

---

## 5. Design Benefits

- Eliminates noisy reboot alerts during patching
- Guarantees visibility into failed or stuck VMs
- Uses **simple naming-based filtering** (no complex logic or tags)
- Scales cleanly across environments and teams
- Easy to audit and explain during incidents or reviews

---

## 6. Summary

This configuration intentionally separates:
- **Detection speed** (short-duration alerts)
- **Operational significance** (long-duration alerts)

By combining tiered alerts with targeted suppression, it provides a reliable, low-noise monitoring strategy suitable for production environments.

