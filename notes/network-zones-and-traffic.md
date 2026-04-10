# Networking Notes

## Traffic Directions: North–South vs East–West

### North–South Traffic

**Definition:** Traffic that moves *into or out of* a network boundary.  
This is perimeter-facing traffic.

**Typical actors:**

*   End users
*   External clients
*   Public services
*   Internet-facing servers

**Examples:**

*   User → public website
*   Internet → API endpoint
*   Internal system → internet

**Visibility:**

*   Easier to monitor
*   Typically enforced at the edge

**Security focus:**

*   Perimeter firewalls
*   Gateways
*   DDoS protection

**Summary:**  
Edge-facing, user-visible, perimeter security.


### East–West Traffic

**Definition:** Traffic that moves *within* a network boundary.  
This is internal, lateral traffic.

**Typical actors:**

*   Internal services
*   Servers
*   Databases
*   Containers / pods

**Examples:**

*   App → database
*   Service → service
*   Pod → pod
*   Internal backups or replication

**Visibility:**

*   Harder to see
*   Often invisible without segmentation and logging

**Security focus:**

*   Lateral movement control
*   Segmentation
*   Microsegmentation
*   Internal inspection

**Summary:**  
Internal, service-to-service, lateral security.


### Why the Distinction Matters

*   Traditional networks: mostly **North–South**
*   Modern/cloud-native networks: **East–West dominates**
*   Breaches often start at the perimeter but **spread laterally**
*   Without East–West controls, attackers move silently


## Zones and Network Segmentation

All major security frameworks require **network segmentation** based on:

*   Trust
*   Sensitivity
*   Function

> **Important:** There is **no global standard** for zone color meanings.  
> Colors are conventions, not requirements.


## Common Zone Color Coding (Convention-Based)

###  Red Zone — Public / High Risk

**Trust level:** Untrusted  
**Purpose:** Internet-facing services  
**Access rules:**

*   Can be accessed from the internet
*   No access to internal zones

**Examples:**

*   Public web server
*   Mail gateway
*   External DNS


###  Yellow Zone — Restricted

**Trust level:** Mostly untrusted  
**Purpose:** Internal systems with non-critical data  
**Access rules:**

*   May reach Red (internet)
*   Must not directly reach Green

**Examples:**

*   Customer portals
*   HR systems
*   Procurement apps


###  Blue Zone — Guests / Partly Trusted

**Trust level:** Partly trusted  
**Purpose:** Guest or visitor access  
**Access rules:**

*   Can access Red / public services
*   No access to Green


###  Green Zone — Internal / Trusted

**Trust level:** Highly trusted  
**Purpose:** Core internal network  
**Access rules:**

*   May access other zones (subject to policy)

**Examples:**

*   Employee workstations
*   Internal servers
*   Databases
*   Dev environments


## Why Use Zones?

*   **Security isolation:** Limits lateral movement
*   **Traffic control:** Enforces least privilege
*   **Compliance:** Supports ISO 27001, PCI, etc.
*   **Zero Trust alignment:** No implicit trust between zones


## Example Zone Layout

*   **Red:** Public web server
*   **Blue:** Guest Wi‑Fi
*   **Yellow:** Customer portal
*   **Green:** Employee LAN and internal servers

## Internal Firewalls & Modern Zoning

### Internal Segmentation Firewalls (ISFW)

Modern networks often place **firewalls between internal zones**, not just at the perimeter.

This is known as:

*   **Internal Segmentation**
*   **East–West traffic inspection**

**Key points:**

*   Firewalls sit *inside* the network
*   Traffic between zones is inspected and logged
*   Lateral movement is restricted after a breach

**Vendor position:**

*   Fortinet explicitly defines **ISFWs** as controls for **East–West traffic**
*   Modern firewalls are **zone-centric**, not edge-only
*   Inter-zone traffic is often denied by default


## Enforcment

Colors and names don’t matter — **enforcement does**.

###  Mandatory principles

*   Guest / untrusted ≠ internal
*   Guest networks **must not** access internal LAN
*   Public-facing services **must** be isolated (DMZ or equivalent)
*   Inter-zone traffic must be:
    *   Defined
    *   Minimal
    *   Justified
    *   Explicitly enforced

###  Naming is flexible

Auditors accept:

*   External / Internal / Trusted
*   Prod / Corp / Guest
*   Zone 0 / Zone 1 / Zone 2

> **Trust boundaries matter — not labels.**


## Key Takeaways

*   North–South = perimeter traffic
*   East–West = internal traffic
*   Modern threats spread laterally
*   Internal firewalls are now common
*   Segmentation + inspection limits blast radius
*   Colors are mnemonic; controls are real


## References

*   <https://www.baeldung.com/cs/network-traffic-north-south-east-west>
*   <https://creately.com/guides/east-west-traffic-vs-north-south/>
*   <https://acato.co.uk/security-zone/>
*   <https://wiki.nethserver.org/doku.php?id=userguide:network_planning>
*   <https://watchdogsecurity.io/iso-27001/segregation-of-networks>
*   <https://www.fortinet.com/content/dam/fortinet/assets/white-papers/wp-isf-security-where-you-need-it-when-you-need-it.pdf>
*   <https://www.cisco.com/c/en/us/support/docs/security/ios-firewall/98628-zone-design-guide.html>