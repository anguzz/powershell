#  SMB Signing Policies – Personal Notes

##  General SMB Signing Overview

SMB (Server Message Block) signing is a security mechanism that protects SMB traffic from tampering and relay attacks by validating the authenticity of the traffic using digital signatures.

Enforcing SMB signing improves security, especially in environments with sensitive file shares or legacy protocols. However, it can introduce **compatibility issues** with older or unmanaged devices that don’t support signing (e.g., printers, scanners, NAS units). 

It seems fine to enforce SMB signing in most modern enviroments. Mostly it's important to watch out for old windows versions and embedded systems that never got SMBv2 don't support it. This might include Industrial controllers, medical equipment and older NAS. 


SMBv2 was released ~2008. So timelapse wise these would be devices to watch out for. 

| Year            | Event / Protocol                                  | Notes                                                               |
| --------------- | ------------------------------------------------- | ------------------------------------------------------------------- |
| **1980s–1990s** | SMBv1 (CIFS)                                      | No signing required by default, very insecure by today’s standards. |
| **2006–2007**   | SMBv2 introduced in Vista / Server 2008           | Faster, supports signing, but some old devices never got updates.   |
| **2009**        | Windows 7 / Server 2008 R2                        | SMBv2 adoption becomes mainstream.                                  |
| **2012**        | SMBv3 in Windows 8 / Server 2012                  | Adds encryption, performance boosts, more secure signing.           |
| **2017**        | Microsoft disables SMBv1 by default in Windows 10 | Push to modern SMB security practices.                              |


Lastly another important thing to watch out for is enabling SMB may consume additional CPU resources on both the client and the server to generate and validate signatures for each packet. On modern hardware, this impact is usually negligible (1-15% depending on the workload).

---

##  Policy 1: Microsoft network client – Digitally sign communications (Always)

- **Role:** Client  
- **Effect:** Enforces SMB signing on **all outbound** SMB connections.  
- **Behavior:** If the target server does **not** support signing, the connection fails.  
- **Use Case:** Improves outbound SMB security for managed devices.

---

##  Policy 2: Microsoft network client – Digitally sign communications (If server agrees)

- **Role:** Client  
- **Effect:** Negotiates SMB signing if the server supports it.  
- **Behavior:** Falls back to unsigned SMB if the server doesn’t require signing.  
- **Use Case:** Compatibility fallback. Not as secure. Optional when “Always” is enforced.

---

##  Policy 3: Microsoft network server – Digitally sign communications (Always)

- **Role:** Server  
- **Effect:** Requires SMB signing for **all inbound** connections.  
- **Behavior:** If the connecting client doesn’t support signing, the connection fails.  
- **Use Case:** Improves protection of shared folders, blocks insecure inbound SMB.  
- ** Risk:** May break scan-to-folder workflows or connections from non-domain/legacy devices.

---

##  Policy 4: Microsoft network server – Digitally sign communications (If client agrees)

- **Role:** Server  
- **Effect:** Enables SMB signing if the client supports it.  
- **Behavior:** Falls back to unsigned SMB if the client doesn’t request it.  
- **Use Case:** Lower security but preserves compatibility. Optional if “Always” is enforced.

---

##  Deployment Strategy

- **Split** SMB client and server settings into **separate Intune policies**:
  1. `Enforce SMB signing – Client` *(Already deployed)*
  2. `Enforce SMB signing – Server` *(New policy)*

- **Test server policy** on personal device + local users to evaluate compatibility.

- If successful, expand testing to **one location** before org-wide rollout.

---

##  References

- Microsoft Docs:  
  [MicrosoftNetworkServer_DigitallySignCommunicationsAlways – Policy CSP](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-localpoliciessecurityoptions#microsoftnetworkserver-digitallysigncommunicationsalways)
