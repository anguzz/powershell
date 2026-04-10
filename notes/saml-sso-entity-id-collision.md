# SAML SSO – Multi‑Tenant Service Provider Entity ID Collision

## Context / What Problem This Explains

This documents a **SAML Single Sign‑On (SSO) failure mode** that occurs when **multiple application environments (tenants)** are integrated with a **single Identity Provider (IdP)** but **share the same Service Provider (SP) identity**.

When this happens, users may successfully authenticate but get redirected to the **wrong environment**.

This behavior is **expected within the SAML standard** and is caused by **Service Provider metadata design**, not an IdP issue.



## The Problem (Plain English)

We have **two separate application environments**, for example:

*   `env-a.example.com`
*   `env-b.example.com`

Both environments are configured with:

*   The **same SP Entity ID**
*   The **same Reply URL (ACS URL)**
*   The **same Reply URL index** (for example: `index = 1`)

### Result

The Service Provider cannot determine **which environment** the user intended to access, so:

*   Authentication succeeds
*   The user is redirected to the **wrong environment**



## Why the Reply URL *Index* Matters

In SAML:

*   A Service Provider can expose **multiple Assertion Consumer Service (ACS) URLs**
*   Each ACS URL is assigned an **index value** (`1`, `2`, etc.)
*   The **index** is used by the SP to decide **where to route the authentication response**

In this scenario:

> The Service Provider is effectively saying:  
> “Use this index value to determine which environment the user should return to.”

If **multiple environments share the same index**, deterministic routing is impossible.



## Current State (Observed)

*   Two separate environments
*   Both advertise:
    *   The same **SP Entity ID**
    *   The same **Reply (ACS) URL**
    *   The same **Reply URL index**

This creates a **shared identity boundary** across environments.



## Root Cause

The root cause is the use of a **shared Service Provider identity** across multiple environments.

When multiple environments:

*   Share an SP Entity ID
*   Share ACS URLs
*   Share index values

 The Identity Provider receives **no reliable signal** to distinguish between environments.

This is a **Service Provider configuration and design limitation**, not an IdP misconfiguration.



## Correct & Supported Fix (Standards‑Aligned)

The correct solution is to use **tenant‑specific (environment‑specific) SP identities**.

###  Tenant‑Specific SP Entity IDs

Each environment should expose:

*   A **unique SP Entity ID**
*   Environment‑specific **Reply (ACS) URLs**
*   Environment‑specific **Logout (SLO) URLs**
*   A **unique Reply URL index**

This ensures deterministic routing after authentication.



## Required Changes

### Service Provider (Per Environment)

For **each environment**:

*   Generate **environment‑specific SP metadata**
*   Ensure metadata includes:
    *   A unique **Entity ID**
    *   Environment‑specific **ACS URLs**
    *   Environment‑specific **Logout URLs**
    *   Distinct **ACS index values**



### Identity Provider

For **each environment**:

*   Register a **separate application / trust**, or
*   At minimum configure:
    *   The environment‑specific **Entity ID**
    *   The correct **Reply (ACS) URL**
    *   A **unique Reply URL index**

Example:

*   `Environment A → index 1`
*   `Environment B → index 2`



## Logout URL Consideration (Important)

If logout endpoints are shared:

*   Logging out of one environment may:
    *   Invalidate sessions for another environment
    *   Cause unexpected re‑authentication flows

Environment‑specific SP metadata ensures logout behavior is **properly scoped**.

## Why This Is *Not* an Identity Provider Issue

*   Identity Providers consume **SP metadata as‑provided**
*   The Service Provider defines:
    *   Entity ID
    *   ACS URLs
    *   Index behavior
*   If multiple environments publish identical metadata, the IdP **cannot disambiguate routing**

The fix must occur **on the Service Provider side**.



## Key Takeaways

*   **Same Entity ID + same Reply URL + same index = broken multi‑environment SSO**
*   Multi‑tenant applications must use **environment‑specific SP identities**
*   This is an **identity boundary and routing issue**, not claims, access, or MFA related
*   The solution is standards‑aligned and expected in SAML design



## TL;DR

> In SAML, the Identity Provider selects the Assertion Consumer Service (ACS) endpoint (by URL or index) based on Service Provider metadata.
> If multiple environments share these values, routing breaks.  
> Environment‑specific SP Entity IDs restore deterministic behavior.



## Reusable Template Metadata

    Title: SAML SSO – Multi‑Tenant Service Provider Entity ID Collision
    Category: Identity / SAML / Authentication Architecture
    Issue: Shared SP Entity ID and Reply URL index across environments
    Resolution: Use environment‑specific SP Entity IDs and ACS indexes



## Generic ASCII Diagram

###  Broken State – Shared SP Identity
```
    ┌──────────────┐
    │     User     │
    └──────┬───────┘
           │
           ▼
    ┌────────────────────┐
    │ Identity Provider  │
    └──────┬─────────────┘
           ▼
    ┌──────────────────────────────┐
    │ Service Provider (shared)    │
    │ Entity ID: shared-sp-id      │
    │ ACS Index: 1                 │
    └──────┬───────────────┬──────┘
           │               │
           ▼               ▼
    ┌──────────────┐   ┌──────────────┐
    │ Environment A│   │ Environment B│
    │  index = 1   │   │  index = 1   │
    └──────────────┘   └──────────────┘

     Cannot reliably route users
```


###  Correct State – Environment‑Specific SP Identities


```
    ┌──────────────┐
    │     User     │
    └──────┬───────┘
           │
           ▼
    ┌────────────────────┐
    │ Identity Provider  │
    └──────┬─────────────┘
           ▼
    ┌──────────────────────────────┐
    │ Service Provider (Env A)     │
    │ Entity ID: sp-env-a          │
    │ ACS Index: 1                 │
    └──────────────┬───────────────┘
                   ▼
            ┌──────────────┐
            │ Environment A│
            │  index = 1   │
            └──────────────┘


    ┌──────────────────────────────┐
    │ Service Provider (Env B)     │
    │ Entity ID: sp-env-b          │
    │ ACS Index: 2                 │
    └──────────────┬───────────────┘
                   ▼
            ┌──────────────┐
            │ Environment B│
            │  index = 2   │
            └──────────────┘

     Deterministic routing
     Clean identity boundaries
```


Now in plain english:

1) User goes to app
2) App says: “Go login with IdP”
3) IdP logs them in
4) IdP sends them back to the app

- The problem is step 4: “where exactly do I send them back?”

There are only 2 important things:

1. Entity ID
“Which app is this?”
Think: App identity

2. ACS URL / Index
“Where inside that app do I send the user?”
Think: Return endpoint


issue config
```
| Setting   | Env A | Env B |
| --------- | ----- | ----- |
| Entity ID | SAME  | SAME  |
| ACS URL   | SAME  | SAME  |
| Index     | SAME  | SAME  |
```

then to fix it this was changed to
```
| Setting   | Env A    | Env B    |
| --------- | -------- | -------- |
| Entity ID | sp-env-a | sp-env-b |
| ACS URL   | A URL    | B URL    |
| Index     | 1        | 2        |
```

SAML routing depends on unique identity (Entity ID) + unique return endpoint (ACS/index)