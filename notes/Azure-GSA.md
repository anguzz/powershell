# Global Secure Access (GSA) 

## High‑Level Concept

*   **Identity‑based access model**
    *   Access follows the **user identity**, not the network
    *   Policies evaluate:
        *   **Who the user is**
        *   **Device posture**
        *   **Session risk**
        *   **What specific resource is being accessed**
    *   Access is granted **per resource / per session**, not per network

*   **Not a traditional VPN**
    *   Does **not** place the user “on the corporate network”
    *   Does **not** create a broad L3/L4 tunnel
    *   Instead:
        *   Acts as an **identity‑aware access broker**
        *   Enforces **Conditional Access at the network access layer**

*   **Targets users rather than devices**
    *   Useful for **AVD / Windows 365** where devices are ephemeral
    *   Identity remains stable even when devices are short‑lived
    *   Reduces reliance on device‑centric or IP‑centric controls

### VPN model

    Authenticate once
    ↓
    Tunnel opens
    ↓
    Network is trusted
    ↓
    Access happens inside the network

### Global Secure Access model

    Attempt access to resource
    ↓
    Entra ID evaluates identity + device + risk
    ↓
    Access granted only to that resource
    ↓
    Evaluation continues during session


## How GSA Differs from a Traditional VPN (Key Mental Model)

### Traditional VPN

*   Authenticate once → **network tunnel opens**
*   User is effectively **inside the network**
*   Trust is largely:
    *   Network‑based
    *   IP‑based
*   Limited visibility into:
    *   Per‑app access
    *   Mid‑session risk changes
*   Higher lateral‑movement risk once connected

### Global Secure Access

*   **No broad network trust**
*   Access decisions are:
    *   **Identity‑first**
    *   **Per resource**
*   Each access attempt is evaluated against:
    *   Entra ID
    *   Conditional Access
    *   Device compliance
    *   Risk signals
*   Access is **continuously re‑evaluated** during the session (CAE)

> GSA behaves like an **always‑on client**, but instead of granting network access, it **authorizes access per resource using identity context**.



### AVD / Windows 365 + GSA

Where AVD could be used.
*   Apply **GSA agent** to AVD / W365 machines
*   Treat AVD session hosts as:
    *   Identity‑driven access points
    *   Not trusted network locations
*   Grant **specific resource access** based on:
    *   User identity
    *   Group membership
    *   Session context
*   Use GSA as a **front‑door access control layer**
    *   Instead of network ACLs
    *   Instead of broad VPN connectivity


## Blocking & User Experience

*   If a user is blocked by GSA:
    *   Enforcement happens **via the GSA agent**
    *   Block occurs **before access to the resource**
    *   No “connected but broken” VPN state
*   Block messaging configuration:
        Entra Portal → Global Secure Access → Add Block Message
*   Question explored:
    *   *How does this present to the end user visually (browser, app, system UI)?*


## Continuous Access Evaluation (CAE)

*   **Session‑level enforcement**
    *   Access is not “granted once and forgotten”
    *   Sessions are **continuously evaluated**

*   **Token protection**
    *   Uses **token binding**
    *   Helps prevent token replay if credentials are stolen

*   **GSA client (G2A)**
    *   Extends CAE to network access
    *   Continuously validates:
        *   Identity
        *   Device compliance
        *   Risk posture

*   **PRT (Primary Refresh Token)**
    *   Stored in **TPM**
    *   Protects against MITM and replay attacks
    *   If token is reused from a different location:
        *   CAE + Conditional Access can immediately block

        ## Device Context

*   Most devices are **Hybrid Joined**
*   Enforcement is still **identity‑first**
*   Device state enhances decisions but does not replace identity
*   Supports Zero Trust even in hybrid environments


## Universal Tenant Restrictions

*   Scenario:
    *   User attempts to authenticate into:
        *   A **different Entra ID tenant**
        *   From a device joined to another tenant
*   Behavior:
    *   Access may be restricted or blocked
*   Note:
    *   Requires deeper review and testing
    *   Relevant for cross‑tenant and partner scenarios


## Zero Trust Network Access (ZTNA)

*   GSA aligns strongly with ZTNA principles:
    *   No implicit trust
    *   No broad network access
    *   Explicit access per resource
    *   Identity‑driven authorization
*   Network connectivity becomes:
    *   Scoped
    *   Intent‑based
    *   Continuously evaluated


## Defender for Cloud Apps (DCA) vs GSA

### Defender for Cloud Apps (DCA)

*   App‑level governance
    *   Sanction / unsanction apps
    *   Data visibility
    *   Session controls
*   Operates **above the network layer**

### Global Secure Access

*   Network‑adjacent enforcement
*   Works closer to:
    *   NIC
    *   Traffic path
*   Focuses on **how access happens**, not app classification

> DCA = *what apps are used*  
> GSA = *how access is granted*


## Deployment / Setup Notes

*   Enable **Traffic Forwarding**
*   Deploy **GSA client**
*   Remote networks:
    *   Supported
    *   Less granular than Private Access

### Private Networks

*   Define **IP address ranges**
*   Ensure traffic:
    *   Does not exit uncontrolled paths
    *   Routes through SSE
*   Define **target addresses**
*   Use **Quick Access** for direct internal routing (ex: PNC server)


## Testing Considerations

*   Leave **Private Access sensors** out of initial testing
*   Maintain **break‑glass account**
    *   Not enabled initially
    *   Required for emergency access


## Logging & Diagnostics

*   Diagnostic settings:
        Edit Settings → Network → Enable all 4 options
*   Logs sent to **Log Analytics Workspace**

### Content Hub

*   Enable **GSA Connector**
*   Creates:
        GSA - {name}

### Cost Notes

*   Logs can be **high‑volume**
*   Rough estimate mentioned: \~3 GB
*   Monitor ingestion closely


## Security Profiles & Policy Enforcement

*   Security profiles enforce **policy‑based blocking**
*   Example:
    *   Block **LinkedIn**
    *   Target:
        *   Internet Access Profile
    *   Conditions:
        *   Identity
        *   Session context
    *   Enforcement:
        *   Applied via GSA security profile


## GSA Traffic Profiles

### Microsoft Traffic Profile

*   Handles Microsoft‑owned services and endpoints

### Private Access Profile

*   Used for internal/private resources
*   Controlled via IP ranges and target addresses

### Internet Access Profile

*   Governs general internet traffic
*   Can apply:
    *   Block
    *   Allow
    *   Restrict policies


## Key Takeaway

*   GSA enforces **identity‑first access**
*   Access decisions follow the **user**, not the network
*   **Not a VPN replacement by tunneling — a replacement by design**
*   Strong fit for:
    *   AVD / Windows 365
    *   ZTNA
    *   Least‑privilege, per‑resource access
*   **Enterprise App Conditional Access always wins**