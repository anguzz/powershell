# Windows 365 vs. Azure Virtual Desktop (AVD) — Summary Note

Windows 365 and Azure Virtual Desktop (AVD) both deliver Windows desktops from Azure, but they are built for very different operating models.

Windows 365 is a fully managed, per‑user Cloud PC with fixed monthly pricing. Each user gets a dedicated virtual desktop with minimal IT effort required. It prioritizes simplicity, predictability, and ease of deployment over flexibility.

Azure Virtual Desktop (AVD) is a customer managed virtual desktop platform with usagebased pricing. It supports multi‑session desktops, pooled resources, and advanced customization, making it ideal for organizations that want maximum flexibility and cost optimization at the cost of greater administrative complexity.

In short:

Choose Windows 365 for simplicity, predictable costs, and low operational overhead

Choose AVD for flexibility, scale, shared desktops, and pay per use pricing

## High‑level Overview

*   **Both** Windows 365 and Azure Virtual Desktop (AVD) run on **Azure**
*   They solve similar problems (virtual desktops) but use **very different models**
*   Main differentiators:
    *   Pricing model
    *   Management responsibility
    *   Flexibility vs simplicity
    *   Multi‑session support

***

## Windows 365 (Cloud PC)

### Core Concept

*   **Single‑user Cloud PC**
*   Fixed hardware configuration (CPU, RAM, storage)
*   **Fixed monthly cost per user**, regardless of usage
*   Comparable to *leasing a physical PC in the cloud*

***

## Windows 365 Editions

### Windows 365 Business

**Target audience**

*   SMBs
*   Simple deployments
*   Minimal IT oversight

**Key Characteristics**

*   Max **300 users per tenant**
*   Microsoft‑managed experience
*   Automatic provisioning
*   Limited configurability

**Identity & Networking**

*   **Entra ID Join only**
*   No custom VNet support

**Management**

*   Windows 365 Portal
*   Microsoft 365 Admin Center
*   Limited Intune capabilities

**Security**

*   Basic Conditional Access
*   Advanced security requires **E5 add‑ons**

**Pricing (per user / month)**

*   Basic: \~$31
*   Standard: \~$41
*   Premium: \~$66–$162

### Windows 365 Enterprise

**Target audience**

*   Medium to large enterprises
*   Higher security and control needs

**Key Characteristics**

*   **Unlimited users**
*   Highly customizable
*   Enterprise‑grade management

**Identity & Networking**

*   Entra ID Join
*   **Hybrid Entra ID Join** (via Azure Network Connection)
*   Can integrate with on‑premises networks

**Management**

*   **Microsoft Intune**
*   Group Policy + MDM
*   Microsoft Graph API support
*   Custom images
*   Resize Cloud PCs

**Security**

*   Conditional Access
*   MFA
*   Defender for Endpoint (E5)
*   Enterprise compliance controls

**Licensing Requirements**

*   Windows 10/11 **Enterprise**
*   **Intune**
*   **Entra ID P1**
*   Azure subscription **optional** (required for ANC)

**Pricing**

*   \~$28–$41 per user/month (standard configs)
*   Up to **$315/user/month** (16 vCPU, 64GB RAM, 1TB)

***

## Limitations of Windows 365

*   No Windows multi‑session
*   No AAD DS support
*   No pooled desktops
*   Pay whether used or not

***

## Azure Virtual Desktop (AVD)

### Core Concept

*   **Infrastructure‑driven virtual desktops**
*   Highly flexible and customizable
*   **Pay‑as‑you‑go** billing
*   Customer manages infrastructure

***

## AVD Deployment Models

### Personal Desktops

*   One VM per user
*   Persistent desktop
*   Comparable to Windows 365 Cloud PC
*   More expensive than pooled hosts

**Use cases**

*   Power users
*   High‑performance or specialized workloads

***

### Pooled Host Desktops (Multi‑session)

**Key Feature**

*   **Windows 10/11 Enterprise multi‑session**
*   Multiple users share VMs
*   Load‑balanced sessions

**Persistence**

*   User data preserved via FSLogix
*   Consistent experience across sessions

**Ideal for**

*   Call centers
*   Task workers
*   General office users
*   Large-scale deployments

**Advanced Capabilities**

*   Custom CPU / GPU / RAM configs
*   RemoteApp (publish apps only)
*   Acts like a secure app delivery PaaS

***

## Identity & Infrastructure (AVD)

*   Requires **Azure subscription**
*   Requires **Entra ID tenant**
*   Session hosts join:
    *   Azure AD Domain Services (AAD DS)
    *   Hybrid AD environments

***

## Management (AVD)

*   Azure Portal
*   PowerShell
*   REST APIs
*   Third‑party tools available:
    *   Citrix
    *   Nerdio
    *   Workspot

**Tradeoff:**   Maximum flexibility  
Higher operational complexity

***

## Pricing Comparison

### Billing Model

| Feature             | Windows 365          | Azure Virtual Desktop    |
| ------------------- | -------------------- | ------------------------ |
| Pricing             | Fixed per user/month | Usage‑based (per second) |
| Cost predictability | High                 | Variable                 |
| Billing when idle   | Still charged        | No charge if VM off      |
| Savings options     | Annual billing       | Reserved Instances       |

### Licensing

*   **Windows 365**
    *   License includes OS rights
    *   Requires Intune + Entra ID P1 (Enterprise)

*   **AVD**
    *   Requires:
        *   Microsoft 365 or Windows Enterprise w/ AVD rights
        *   Azure subscription
        *   Identity infrastructure

***

## When to Choose Windows 365
 Choose Windows 365 if:

*   You want **simplicity**
*   Predictable budgeting is required
*   Minimal IT administration
*   Per‑user dedicated desktops
*   SMB or remote workforce

***

## When to Choose Azure Virtual Desktop
 Choose AVD if:

*   You need **multi‑session**
*   Your workload usage varies
*   Cost optimization is important
*   You have Azure expertise
*   Large or complex user bases
*   Need RemoteApp delivery

***

## When to Choose Neither

Neither is ideal if:

*   No Azure footprint exists
*   No Azure / VDI expertise
*   Very small org (<50 users, situational)
*   Simple security needs
*   Static, non‑remote workforce

***

## Key Takeaway

> **Windows 365 trades flexibility for simplicity.  
> AVD trades simplicity for flexibility and cost efficiency.**

Most organizations:

*   Start with **Windows 365** for ease
*   Move to **AVD** as scale, complexity, or cost optimization becomes critical