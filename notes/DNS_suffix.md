
#  DNS Suffix Configurations 

## Overview
In Windows environments, DNS suffixes control how hostnames are resolved and how a device forms its fully qualified domain name (FQDN). This can be configured via Intune to ensure consistent resolution and domain behavior, especially in multi-site or hybrid environments.

---

##  Primary DNS Suffix

- This defines the **FQDN** of the device:  
  > `hostname.internal.domain.com`
- Used for:
  - Active Directory registration
  - Kerberos authentication
  - DNS dynamic updates
- **Only one** can be set per device.

**Configured via Intune:**
```
Settings Catalog > Network > DNS Client > Primary DNS Suffix
Value: internal.domain.com
```

---

##  DNS Suffix Search List

- Used when resolving **unqualified hostnames** like `server01`
- Windows tries appending each domain in the list in order until resolution succeeds
- Helpful when:
  - Devices travel across sites/subnets
  - Internal services use different subdomains
  - Users/scripts omit FQDNs

**Configured via Intune:**
```
Settings Catalog > Network > DNS Client > DNS Suffix Search List
Value: internal.domain.com, domain2.local, domain3.local
```

**Resolution Example:**
```
ping server01 ➜
  server01.internal.domain.com ➜ no DNS record?
  server01.domain2.local ➜ success
```

---

##  Notes

- Devices will **use the Primary DNS Suffix for self-identification**, but the search list acts as a **fallback for resolving others**.
- You can view current suffix settings with:
  ```powershell
  ipconfig /all
  ```
- Useful registry paths:
  ```
  HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters
  ```

---
