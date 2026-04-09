# Kerberos vs NTLM — Notes

## High‑Level Summary

*   **NTLM** is a legacy, hash‑based authentication protocol that enables credential replay and lateral movement once hashes are stolen.
*   **Kerberos** is a ticket‑based authentication protocol that avoids sending password material and significantly reduces replay risk.
*   Microsoft is actively **phasing out NTLM** and moving Windows environments to **Kerberos‑first / Kerberos‑only** authentication due to longstanding security failures.

***

## NTLM (Why It’s Weak)

### What NTLM Is

*   Legacy Windows authentication protocol dating back to the 1990s
*   Uses a **challenge‑response** model driven by **password hashes**
*   Commonly used today as a **fallback** when Kerberos fails

### Core Security Problems

*   No mutual authentication (client cannot verify server identity)
*   Authentication is based on reusable **NT password hashes**
*   Vulnerable to:
    *   Pass‑the‑Hash attacks
    *   NTLM relay attacks
    *   Replay and man‑in‑the‑middle attacks

### Key Issue

> NTLM treats the password hash as the credential.  
> If the hash is stolen, the attacker can authenticate without ever knowing the password.

***

## Kerberos (Why It’s Better)

### What Kerberos Is

*   Ticket‑based authentication protocol
*   Default in Windows environments since Windows 2000
*   Backed by a trusted **Key Distribution Center (KDC)** (the domain controller)

### Security Advantages

*   Passwords are **never sent over the network**
*   Uses **time‑limited tickets** instead of reusable hashes
*   Supports:
    *   Mutual authentication
    *   Single Sign‑On (SSO)
    *   Delegation and modern MFA scenarios

### Result

*   Credential theft is harder to reuse
*   Authentication artifacts expire quickly
*   Lateral movement is more constrained

***

## Why Microsoft Is Deprecating NTLM

### Current Status

*   NTLM was **formally deprecated in June 2024**
*   It **no longer receives security updates**
*   Microsoft is transitioning Windows to **disable NTLM by default**

### Microsoft’s Three‑Phase Plan

1.  **Enhanced auditing and visibility**  
    Identify where NTLM is still being used
2.  **Kerberos compatibility improvements**  
    Reduce edge cases that previously required NTLM
3.  **NTLM disabled by default**  
    Future Windows Server and Windows client releases require explicit re‑enablement

### Why This Matters

NTLM is a core enabler of:

*   Credential replay
*   Lateral movement
*   Domain compromise
*   Ransomware propagation

***

## Pass‑the‑Hash (Why NTLM Is So Abusable)

### Concept (Defender‑Level Overview)

*   NTLM authentication proves knowledge of a hash
*   The hash itself functions as a **bearer token**
*   If an attacker extracts a hash from memory, they can reuse it directly for authentication

### Why NTLM Enables This

*   No binding to:
    *   Device
    *   Session
    *   Time window
*   The same hash works anywhere NTLM is accepted

### Why Kerberos Helps

*   Uses **tickets**, not raw hashes
*   Tickets:
    *   Expire
    *   Are scoped to specific services
    *   Are harder to replay at scale

***

## Security Takeaway

*   **NTLM** = identity‑based lateral‑movement fuel
*   **Kerberos** = identity containment and blast‑radius reduction
*   Disabling NTLM:
    *   Breaks common post‑exploitation paths
    *   Forces attackers into noisier, higher‑friction techniques
    *   Is a prerequisite for modern, identity‑centric security models

***

## References

*   Pure Storage – Kerberos vs NTLM  
    <https://blog.purestorage.com/purely-educational/kerberos-vs-ntlm/>

*   JumpCloud – NTLM vs Kerberos  
    <https://jumpcloud.com/blog/ntlm-vs-kerberos>

*   The Hacker News – Microsoft Begins NTLM Phase‑Out  
    <https://thehackernews.com/2026/02/microsoft-begins-ntlm-phase-out-with.html>