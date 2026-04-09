# Entra ID Access Packages 

## Why Access Packages Are Needed

*   Provide **governed, time‑bound access** to apps, groups, and roles
*   Reduce **standing access** and manual onboarding/offboarding work
*   Enable **self-service access requests** with approvals
*   Support **least privilege** and compliance (audits, access reviews)
*   Useful for **employees, contractors, vendors, and partners**

***

## What an Access Package Is

An **Access Package** is a bundle of:

*   Azure AD **Groups**
*   **Enterprise Applications**
*   **SharePoint Online sites**
*   (Optionally) **Entra ID roles**

Delivered to users via:

*   Request + approval workflows
*   Automatic assignment rules
*   Time-bound assignments with expiration

***

## Where You Create Them

**Entra Admin Center**  
`Identity Governance → Entitlement Management → Access packages`

Access Packages live inside:

*   **Catalogs** (logical containers used to delegate ownership and scope access)

***

## High Level Setup Flow

1.  **Create or choose a Catalog**
    *   Define who can manage packages and resources
2.  **Create Access Package**
    *   Add groups, apps, sites, roles
3.  **Define Assignment Policies**
    *   Who can request access (users, guests, external)
    *   Approval requirements (single/multi‑stage)
    *   Access duration (expiration)
4.  **(Optional) Configure Reviews**
    *   Recurring access reviews for long‑lived access
5.  **Publish & Share**
    *   Users request via My Access portal

***

## Assignment Policy Basics

Each access package has **one or more policies** that control:

*   **Eligibility**
    *   Internal users
    *   Specific groups
    *   External users (B2B)
*   **Approvals**
    *   Required / not required
    *   Who approves
*   **Lifecycle**
    *   Start / end date
    *   Auto-expiration
*   **Re-access**
    *   Can users request again after expiration?

***

## Key Things to Keep in Mind

### Design & Governance

*   **Start small**: don’t over-bundle unrelated access
*   One package = **one business role or scenario**
*   Use **separate packages** for:
    *   Read vs admin access
    *   Temporary vs permanent needs

### Lifecycle Management

*   Always set **expiration** where possible
*   Use **access reviews** for long-lived assignments
*   Package removal = **automatic deprovisioning**

### Ownership & Delegation

*   Catalog owners ≠ Entra Global Admins
*   Delegate package management to **app or system owners**
*   Keep security team as **catalog owners**, not day‑to‑day approvers

### Groups & Apps

*   Prefer **security groups** (not M365 groups) for clarity
*   Ensure apps support **group-based assignment**
*   Avoid nesting complexity unless required

### External Access

*   External users request via **My Access**
*   B2B users are still governed by:
    *   Assignment policy
    *   Expiration
    *   Reviews

***

## Common Pitfalls

*   No expiration → access never removed
*   One giant “catch‑all” access package
*   Too many approvers slowing onboarding
*   No clear owner for the catalog/package

***

## References

*   AdminDroid – *How to Create Access Packages in Microsoft Entra*  
    <https://blog.admindroid.com/how-to-create-access-packages-in-microsoft-entra/>
*   Microsoft Learn – *Create an access package in entitlement management*  
    <https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-create>