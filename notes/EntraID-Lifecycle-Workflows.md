# Microsoft Entra ID Governance

## Lifecycle Workflows – Custom Attribute Triggers (Preview)

## High‑Level Summary

Microsoft Entra **Lifecycle Workflows** can now trigger workflows based on **custom attribute changes**, not just built‑in Entra ID attributes. This significantly expands identity governance automation but introduces **non‑real‑time processing delays** for custom attributes.

This feature is best suited for **governance, access lifecycle, and HR‑driven automation**, not immediate security enforcement.

## Supported Attribute Types for Workflow Triggers

Lifecycle Workflows can trigger when changes occur in:

*   **Custom Security Attributes (CSA)**
*   **Directory extension attributes**
*   **EmployeeOrgData attributes**
*   **On‑premises AD extension attributes (1–15)**

These attributes can now be used as **execution conditions** for scheduled workflows.

## Licensing & Prerequisites

*   Requires **Microsoft Entra ID Governance** or **Microsoft Entra Suite**
*   Admin roles required:
    *   Lifecycle Workflows Administrator
    *   Attribute Assignment Administrator
*   Attribute change detection:
    *    Only supported for **scheduled workflows**
    *    Not real‑time or event‑based

## How Attribute Triggers Work (Conceptually)

1.  Attribute value changes (cloud, HR system, or on‑prem AD)
2.  Change propagates through Entra backend services
3.  Lifecycle Workflows detects the change
4.  User is evaluated during the **next scheduled workflow run**
5.  Workflow executes if scope conditions are met

## Key Limitation: Custom Attribute Trigger Delay

### Built‑in Attributes (e.g., Department)

*   Detected quickly (minutes)
*   Processed in the next scheduled run

### Custom Attributes (CSA, extensions, on‑prem)

*   **Detection delay can be up to \~4 hours**
*   Caused by upstream replication and indexing
*   Once detected, workflow runs at the **next scheduled execution**

This delay is **expected behavior**, not a bug.

## Timing Example (From Documentation)

### Regular Attribute

*    Attribute changes
*   User detected in scope
*   Workflow runs and processes user

### Custom Attribute

*   Custom attribute changes
*   Change propagates to Lifecycle Workflows
*   User detected (misses 4pm run)
*   Workflow processes user

## Why This Feature Is Valuable

This enables workflows to respond to **business‑specific or security‑specific signals** that don’t exist as native Entra attributes.

## Practical Enterprise Use Cases

### 1. Role‑Based Access via Custom Security Attributes (CSA)

**Example attributes:**

*   `BusinessUnit = Finance`
*   `PrivilegedRole = VendorAdmin`
*   `DataSensitivityTier = High`

**Workflow actions:**

*   Assign / remove access packages
*   Trigger PIM eligibility
*   Update least‑privilege groups

 Best for security‑driven authorization logic  
 Not suitable for instant access revocation

### 2. HR‑Driven Identity Automation (EmployeeOrgData)

**Trigger examples:**

*   Cost center change
*   Internal transfer flag
*   Worker type update

**Workflow actions:**

*   Remove legacy access
*   Assign new app entitlements
*   Update group membership

 Cleaner than department‑based logic  
 Aligns identity lifecycle with HR source of truth

### 3. Hybrid AD → Cloud Automation

**On‑prem attributes:**

*   `extensionAttribute5 = Manufacturing`
*   `extensionAttribute10 = PrivilegedUser`

**Workflow actions:**

*   Apply sensitivity labels
*   Grant Defender / Sentinel access
*   Adjust Conditional Access scope

 Ideal for hybrid orgs with AD as authority

### 4. Vendor / Contractor Lifecycle Control

**Trigger examples:**

*   `ContractStatus = Expired`
*   `VendorType = External`

**Workflow actions:**

*   Remove Teams / SharePoint access
*   Revoke access packages
*   Disable sign‑in

 Reduces orphaned access  
 Strong governance use case

## When to Use Custom Attribute Triggers

 **Good fit**

*   Identity governance
*   Joiner / mover / leaver automation
*   Access lifecycle management
*   HR‑driven role changes
*   Vendor and contractor access control

 **Not a good fit**

*   Real‑time security enforcement
*   Incident response
*   Immediate access revocation

For those, rely on:

*   Conditional Access
*   PIM
*   Defender / Sentinel automation

## Key Takeaway

 **Custom attribute triggers massively increase flexibility but sacrifice immediacy.**
Think of them as: **“Governance‑grade automation, not real‑time enforcement.”**

## Administrative Units (AUs) and Object Mixing (Lifecycle Workflows Context)

Administrative Units (AUs) can contain **users, groups, and devices in any combination**. With **Delegated Workflow Management (GA)**, Lifecycle Workflows can now be **administratively scoped to AUs**, meaning both **workflow management** and **workflow execution** are limited to the objects within the AU.https://learn.microsoft.com/en-us/entra/id-governance/manage-delegate-workflow

### Key Behaviors

*   AUs may include:
    *   Users
    *   Groups
    *   Devices
*   Objects can belong to **multiple AUs**
*   Adding a **group** to an AU scopes management of the **group object only** (not its members)
*   Lifecycle Workflows:
    *   Execute **only against users within the AU**
    *   Are **visible and manageable only by admins scoped to that AU** [\[learn.microsoft.com\]](https://learn.microsoft.com/en-us/entra/id-governance/manage-delegate-workflow)

### Recommended AU Design Pattern

**Default approach:**  
Use **single‑object‑type AUs**, especially **user‑only AUs**, since Lifecycle Workflows are user‑centric.

 Examples:

*   `AU‑US‑Employees` → Users only
*   `AU‑EU‑Devices` → Devices only
*   `AU‑Finance‑Groups` → Groups only

This keeps:

*   Admin delegation clear
*   Workflow scope predictable
*   Audit and troubleshooting simple

### When Mixing Objects Makes Sense

Mixing users, groups, and devices in the same AU is **intentional** and appropriate **only when the same admins are responsible for all of them**.

 Valid scenarios:

*   Regional IT teams managing **users + their devices**
*   Business‑unit isolation (users, devices, and groups owned together)
*   Aligning workflow execution scope with real operational responsibility

 Avoid mixing if:

*   Different teams manage users vs devices
*   There’s no clear reason for shared admin control
*   The AU becomes a “catch‑all” container

### Rule of Thumb

> **Start with one object type per AU.  
> Mix only when the same administrators must manage multiple object types together.**

With Lifecycle Workflows now AU‑scoped, AU design directly affects **who can manage workflows and who workflows can impact**, making deliberate AU structure critical.

Refernce:

https://learn.microsoft.com/en-us/entra/id-governance/workflow-custom-triggers#attribute-vs-custom-attribute-processing-timing

## Custom Security Attributes vs extensionAttribute1–15 (Lifecycle Workflows)

- **Custom Security Attributes (CSA)**  
  - Appear as: `customSecurityAttributes/<AttributeSet>/<AttributeName>`  
  - Tenant-defined, security-scoped, lifecycle-aware  
  - Can be **activated / deactivated**  
  - **Deactivated CSAs do NOT appear** in Lifecycle Workflow scope picker

- **extensionAttribute1–15**  
  - Appear as: `onPremisesExtensionAttributes/extensionAttributeX`  
  - Legacy on‑prem AD / Exchange attributes  
  - Always exist, **no lifecycle state**  
  - Not Custom Security Attributes

- **Key distinction**  
  - If it has an **Attribute Set** → it’s a CSA  
  - If it’s `extensionAttributeX` → legacy on‑prem metadata

- **Lifecycle Workflows**  
  - Support both CSAs and extensionAttribute1–15  
  - CSAs must be **combined with a primary attribute** (e.g. department)

  ## Why Custom Security Attributes vs extensionAttributes

- **extensionAttribute1–15**
  - Simple metadata / flags
  - Usually set from on‑prem AD
  - No ownership, lifecycle, or delegation
  - Best for quick, pragmatic workflow triggers

- **Custom Security Attributes (CSA)**
  - Governance & authorization signals
  - Role‑controlled (who can see / set them)
  - Have lifecycle (can be deactivated)
  - Reusable across:
    - Lifecycle Workflows
    - Access Packages
    - ABAC / security decisions

- **Rule of thumb**
  - “What should we *do*?” → extensionAttribute is fine  
  - “What is this user *allowed to be*?” → use CSA

- **Key insight**
  - CSAs are usually **inputs** to workflows, not outputs  
  - Workflows react to CSAs; they don’t normally manage them