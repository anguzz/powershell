## Overview

Microsoft introduced a **Microsoft-managed Conditional Access policy** called **Block device code flow**.  
This policy blocks authentication attempts that use the **OAuth Device Code Flow** across all cloud applications.

Device code flow is typically used by devices with limited input capabilities (for example smart TVs, CLI tools, or embedded devices) where a user signs in by entering a code on another device.

Microsoft automatically deploys this policy in many tenants as part of baseline security protections.

Default configuration:

- **Scope:** All users  
- **Cloud apps:** All apps  
- **Condition:** Device Code Flow Authentication  
- **Control:** Block access  

The policy is usually enabled in **report-only mode first**, and later enforced automatically by Microsoft.

---

## Impact

When enforcement began, accounts that relied on device code flow authentication were **signed out or blocked from signing in**.

Common scenarios affected:

- Shared service accounts
- Conference room resource accounts
- Legacy automation or scripts using device code login
- CLI tools authenticating via device code

In one scenario, **conference room accounts were signed out** after Microsoft enforced the policy.

---

## Remediation Approach

To prevent disruption to shared resources, certain identities were excluded from the policy.

Steps taken:

1. Identified accounts that required device code flow authentication.
2. Placed those accounts into a **dedicated exclusion group**.
3. Added that group to the **Excluded identities** section of the policy.

Example pattern:

- Create group for exceptions (ex: conference room service accounts)
- Add required accounts to that group
- Exclude the group from the Conditional Access policy

---

## Recommended Best Practices

- Only exclude **service accounts or shared resources that require it**
- Avoid excluding normal user accounts
- Review exclusions periodically
- Monitor sign-in logs for device code flow usage

If possible, migrate services away from device code authentication to more secure methods such as:

- Managed identities
- App registrations with certificates
- Modern OAuth flows

---

## Key Takeaways

- Microsoft may automatically deploy security baseline policies.
- Device Code Flow is increasingly restricted due to abuse risks.
- Shared or legacy accounts may require explicit exclusions.
- Maintain a controlled exception group rather than excluding accounts individually.