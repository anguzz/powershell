# Azure Virtual Machine Scale Sets (VMSS) overview

## What VMSS Is

Azure Virtual Machine Scale Sets (VMSS) let you deploy and manage a **group of identical virtual machines** as a single resource.  
They are designed for workloads that need **scalability, consistency, and resilience** without manually managing individual VMs.

VMSS is commonly used for:
- Stateless application tiers
- Gateways and appliances
- Infrastructure components that must scale or self-heal

---

## Core Problems VMSS Solves

### 1. Scale
VMSS can automatically:
- Add instances when load increases
- Remove instances when load decreases

Scaling behavior is driven by:
- Metrics (CPU, memory, custom signals)
- Manual or scheduled actions

---

### 2. Consistency

All VMSS instances are created from:
- A **single VM model**
- A shared OS image
- A shared network configuration

This prevents configuration drift, which is a common source of:
- Routing issues
- Intermittent failures
- Hard-to-debug behavior differences between VMs

---

### 3. Resiliency / Self‑Healing

If a VMSS instance:
- Fails
- Becomes unhealthy
- Is manually deleted

Azure automatically replaces it with a new instance based on the same model.

This ensures infrastructure recovers **without manual rebuilds**.

---

## VMSS Architecture (Conceptual)

- **Scale Set**  
  The logical container that defines how instances behave

- **Instance**  
  An individual VM created from the scale set model

- **Model / Template**  
  The blueprint defining:
  - OS image
  - Networking
  - Extensions
  - Bootstrapping behavior

Updating the model does not change running VMs until explicitly applied.

---

## Updating VMSS Safely

Key concept:
> VMSS updates are **model-based**, not instance-based.

Typical flow:
1. Update the VMSS model (template)
2. Apply the update to:
   - All instances
   - Or selected instances

This allows:
- Phased rollouts
- Low-risk testing
- Controlled changes

---

## Networking Considerations (High Level)

VMSS tightly integrates with Azure networking:
- Load Balancers
- Application Gateway
- Subnets and NSGs

Important principles:
- All instances share the same network design
- Misconfigured networking in the model affects every instance
- Routing stability depends on consistent next-hop behavior across instances

---

## Automation and Bootstrapping

VMSS instances commonly use:
- VM extensions
- Initialization scripts
- External automation systems

These ensure that when an instance starts, it:
- Configures itself
- Registers with external systems
- Matches the expected operational state



`autoprov_cfg set template -tn "<CONFIGURATION-TEMPLATE-NAME>" -<SOFTWARE-BLADE-NAME>`

This illustrates a common VMSS pattern:

*   A **template defines behavior**
*   Every new instance applies that behavior automatically

The specific tool is implementation-dependent, but the **pattern is universal**.

## When VMSS Is (and Isn’t) a Good Fit

### Good fit:

*   Horizontally scalable services
*   Infrastructure that must auto‑recover
*   Environments where consistency is critical

### Not a great fit:

*   Pet VMs with unique configs
*   Workloads requiring manual per‑VM changes
*   Systems that cannot tolerate instance replacement

***

## Key Takeaways

*   VMSS manages **sets of VMs**, not individual machines
*   The **model is the source of truth**
*   Consistency prevents subtle failures
*   Automation is required to fully benefit from VMSS
*   VMSS is foundational for modern, cloud‑native infrastructure


Here’s a cleaner, tighter version with clearer flow and slightly more precise wording:

---

# Connection Draining in Azure VMSS

## What It Is

**Connection draining** (graceful termination) is the process of removing a VM from service **without disrupting active traffic**.

The goal is to:

* Stop **new connections** from reaching the instance
* Allow **existing connections/work** to finish
* Then safely terminate the VM

This is important during:

* Scale-in events
* Updates and rolling deployments
* Platform maintenance

---

## How Azure Actually Handles It

Azure does **not perform true connection draining for you** at the infrastructure level (Standard Load Balancer).

Instead, it provides a **signal**, and your application is responsible for handling shutdown correctly.

---

## Termination Notifications (IMDS)

VMSS uses **Instance Metadata Service (IMDS)** to notify instances before termination.

When enabled:

* The VM receives **advance notice** of:

  * Scale-in events
  * Spot evictions
  * Platform maintenance

This creates a short window where the application can:

* Stop accepting new work
* Gracefully close connections
* Flush state (logs, sessions, queues)
* Perform shutdown logic

---

## Load Balancer Behavior

At the networking layer:

* **Health probes control traffic**

  * When a VM becomes unhealthy → it stops receiving new connections

* **Existing connections**

  * Are **not actively drained by Azure**
  * Continue until:

    * The application closes them, or
    * The load balancer idle timeout is reached

---

## Key Reality

> Azure does not drain connections, it only signals that a VM is about to be removed.

---

## What This Means for Design

To achieve true graceful behavior, your application must:

* Handle termination signals from IMDS
* Fail health checks when shutting down (to stop new traffic)
* Gracefully close in-flight connections
* Assume the VM will be terminated shortly

---

## Takeaway

Reliable VMSS workloads depend on **application-level shutdown logic**, not infrastructure.

If this is not implemented:

* Requests may be dropped
* Sessions may be interrupted
* Users may experience errors during scale-in events

# Autoscaling Patterns in VMSS

## Overview

Azure Virtual Machine Scale Sets (VMSS) rely on **Azure Monitor Autoscale** to automatically add or remove VM instances based on workload demand. Autoscale decisions are driven by **metrics**, evaluated over time, and enforced within predefined minimum and maximum instance limits.

VMSS is designed for **ephemeral infrastructure** — instances are expected to scale out and be removed regularly. 

For example this might work well for cloud firewalls because the instance itself is not the source of truth: configuration, policy, and logging live outside the VM, while load balancers abstract instance identity. As a result, firewall capacity can scale horizontally and individual instances can be replaced without impacting traffic. 

The same pattern applies to cloud‑native web applications, where additional application instances can be added or removed to handle changes in demand without affecting availability, as traffic is distributed across the active instances.

## Default Autoscale Behavior (CPU‑Based)

A common starting point for autoscaling uses **average CPU usage across the scale set**:

- **Scale out**
  - Trigger: Sustained high average CPU across instances  
  - Action: Add one VM instance

- **Scale in**
  - Trigger: Sustained low average CPU across instances  
  - Action: Remove one VM instance

Azure evaluates these conditions over consecutive time intervals to avoid reacting to short‑lived spikes or dips.

---

## Observed Scaling Flow (Example)

A typical autoscale lifecycle looks like:

1. Load increases across the VMSS
2. Average CPU exceeds the configured threshold
3. Azure **adds a new instance**
4. Load normalizes over time
5. After a sustained period of low utilization:
   - A **scale‑in event triggers**
   - Azure **removes a VM instance**

Instance removal is automatic and expected behavior.

---

## Autoscaling on Custom Metrics (Beyond CPU)

CPU is often a **proxy**, not a perfect signal.

Azure Autoscale also supports scaling based on:
- Application‑level metrics
- Connection or session counts
- Queue depth
- Throughput indicators

These metrics are:
- Emitted by the workload or platform
- Collected by Azure Monitor
- Used directly in autoscale rules

This allows scaling decisions to reflect **actual demand**, not just resource consumption.

## Example: Metric‑Driven Scale Logic (Abstract)

Instead of CPU, autoscale rules might use a workload‑specific signal such as:

- Number of active connections per instance
- Average sessions per node
- Requests per second normalized by instance count

Typical configuration elements:
- Metric aggregation method (Average)
- Optional division by instance count
- Thresholds for scale in and scale out
- Incremental scaling (+1 / −1 instance)

This pattern ensures capacity expands and contracts in proportion to real usage.

---

## Autoscale Rule Behavior

- **Scale‑out rules**
  - Trigger when *any* configured rule is met (logical OR)

- **Scale‑in rules**
  - Trigger only when *all* scale‑in conditions are met (logical AND)

This prevents aggressive scale‑in during temporary dips in load.

---

## Operational Considerations

- Autoscale events are **host‑driven**, not application‑aware
- Instances may be added or removed without manual intervention
- New instances must configure themselves automatically
- Removed instances should be assumed to disappear permanently

VMSS workloads must be designed with the expectation that **instance churn is normal**.

## Orchestration Modes

### Uniform (classic VMSS)
- All instances identical
- Managed as a single unit
- Best for stateless workloads

### Flexible (newer model)
- More VM-level control
- Mix of VM sizes/images possible
- Closer to managing individual VMs with scaling

> Most cloud-native workloads use **Uniform**



## Key Takeaways

- VMSS autoscaling is horizontal and metric‑driven
- Default CPU rules are only a starting point
- Custom metrics allow autoscaling to match real demand
- Scale‑in events are expected and frequent in healthy systems
- Applications must tolerate instance replacement

## Common Pitfalls

- Storing data locally on the VM
- Manual changes to instances (lost on replacement)
- Assuming instance persistence
- Not handling termination notifications
- Weak bootstrapping (new instances come up broken)

## References

- Azure VM Scale Sets Overview  
  https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview

- VMSS Networking Concepts  
  https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-networking

- Azure Load Balancer Overview  
  https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-overview

- Azure Monitor Autoscale Overview  
  https://learn.microsoft.com/en-us/azure/azure-monitor/autoscale/autoscale-overview

- Guide to Azure VMSS Termination Notifications  
  https://www.binadox.com/blog/binadox-article-enable-instance-termination-notifications/

- Orchestration modes for Virtual Machine Scale Sets in Azure 
  https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-orchestration-modes