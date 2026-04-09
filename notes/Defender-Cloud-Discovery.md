# Cloud Discovery (Defender for Cloud Apps) 

## What Cloud Discovery Is

Cloud Discovery analyzes **outbound traffic logs** and maps them against the **Microsoft Defender for Cloud Apps catalog (\~31,000 cloud apps)** to identify SaaS usage, Shadow IT, and risk across the environment.

> Discovery does **not** require a firewall or proxy when using Microsoft Defender for Endpoint (MDE) integration.



## Discovery via Microsoft Defender for Endpoint (MDE)

### Endpoint-based discovery (recommended / default in modern tenants)

Defender for Cloud Apps integrates **natively** with Microsoft Defender for Endpoint to:

*   Simplify rollout of Cloud Discovery
*   Extend visibility beyond the corporate network (WFH, roaming devices)
*   Enable **device- and user-aware** investigation

When the discovery source is **Defender-managed endpoints**, all data is coming from **MDE endpoint telemetry**.



## How This Is Typically Set Up (Often Already Done)

In most tenants, this **was not set up explicitly for Cloud Discovery** — it comes as a byproduct of Defender adoption:

1.  Devices onboarded to **Microsoft Defender for Endpoint**
2.  Network telemetry collection enabled (**default behavior**)
3.  Defender for Cloud Apps (MDCA) integration toggle enabled
4.  Users browse the internet → SaaS traffic observed
5.  Microsoft maps domains and traffic to its app catalog
6.  Discovered apps appear (for example: 3,527 apps)



## What Data Is Collected from Endpoints

Once MDE is onboarded, devices send:

*   DNS metadata
*   HTTP/HTTPS metadata
*   TLS / SNI information
*   Destination domain & IP
*   Protocol and port
*   Initiating process context

This data powers:

*   **DeviceNetworkEvents**
*   Cloud Discovery dashboards
*   Discovered Apps in Entra / Defender portals

If Defender for Endpoint **was not onboarded**, tables like `DeviceNetworkEvents` would be empty or nonexistent.



## Quick Validation: Is Your Discovery Endpoint‑Based?

A fast way to confirm discovery is coming from **MDE telemetry** is to use **Advanced Hunting**.

1.  Go to:
        https://security.microsoft.com/v2/advanced-hunting

2.  Run a test query:

```
    kql
    DeviceNetworkEvents
    | where RemoteUrl has "github"
    | summarize count() by DeviceName
```
 If this returns results, Cloud Discovery is being driven by **endpoint telemetry**, not firewall or proxy logs.



## Sanctioned vs Unsanctioned Apps

*   Apps discovered via MDE can be:
    *   **Sanctioned** (approved)
    *   **Unsanctioned** (risky or unapproved)
*   Marking an app as **Unsanctioned**:
    *   Does **not automatically block** it
    *   Enables monitoring, reporting, and governance
    *   Can later be enforced via Defender / Network Protection

Blocking is a **separate enforcement step**, intentionally decoupled from discovery.



## Why This Works (Architecture View)
```
Windows OS
  └── Defender Antivirus
        └── Defender for Endpoint
              └── Network Protection
                    └── Defender for Cloud Apps (Discovery)
```

Key point:

*   Defender for Endpoint sits **inside the OS networking stack**
*   Traffic inspection is **endpoint-local**
*   Works on and off corporate networks
*   Aligns with Zero Trust and identity-centric security models



## Key Takeaways

*   Cloud Discovery is **not firewall-dependent**
*   Endpoint telemetry is often **already enabled**
*   Entra/Defender is **surfacing existing data**, not collecting new traffic
*   Advanced Hunting confirms the data path
*   Discovery ≠ enforcement (on purpose)




## Reference

*   Microsoft Learn – Cloud Discovery setup  
    <https://learn.microsoft.com/en-us/defender-cloud-apps/set-up-cloud-discovery>

## Discovered Apps – What’s Useful to Know

### Why the app details page matters

Clicking a discovered app gives **context for governance**, not just visibility. It helps answer: *Is this app acceptable, risky, or irrelevant?*



### Key signals to pay attention to

**Usage context**

*   Number of users and devices
*   Upload vs download volume
*   Total traffic and transactions
*   Last seen date

Use this to distinguish:

*   Low-risk / low-use noise
*   vs high-use apps moving data



**Security posture**
Common indicators shown:

*   Data at rest encryption (supported or not)
*   MFA support
*   Admin audit logs
*   SAML / federated auth support
*   TLS version and known vulnerability protections

Use this to decide whether an app is **enterprise-viable** at all.



**Compliance indicators**
Flags for standards such as:

*   ISO 27001 / 27018
*   SOC 1 / 2 / 3
*   GDPR (data protection, breach reporting)
*   HIPAA / PCI (where applicable)

Many consumer apps show **partial or unsupported compliance**. This is often enough to justify unsanctioning.



**Legal & privacy signals**

*   Data ownership
*   Data retention
*   Right to erasure
*   Breach notification obligations

Useful for privacy and risk discussions, not enforcement by itself.



**Risk score**

*   Numerical score (1–10) based on \~90 factors
*   Derived from security, compliance, legal, and trust signals

Use this to **prioritize**, not to auto‑block.



### Governance actions

*   Sanctioned: approved
*   Unsanctioned: flagged for monitoring and policy targeting

Important:

*   Unsanctioned does **not** block traffic by default
*   Blocking requires separate enforcement (MDE Network Protection, policies, or APIs)



### Practical takeaway

Discovered Apps helps you:

*   Identify Shadow IT with evidence
*   Prioritize risk based on usage + controls
*   Support governance decisions with facts
*   Separate discovery from enforcement intentionally