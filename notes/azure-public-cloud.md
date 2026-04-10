# Azure Public Cloud 

## Overview

**Azure Public Cloud** is Microsoft’s global cloud platform, providing infrastructure (IaaS), platform (PaaS), and software services (SaaS). It’s the most widely used Azure deployment model (vs. Government or China clouds).

It is made up of globally distributed datacenters and exposes resources via **regions** (e.g. *East US, West Europe*).
Networking, identity, storage, compute, and management services are all delivered through this cloud.

---

## Key Concepts

### Regions

* Each region = a cluster of Microsoft datacenters.
* Public cloud regions are spread worldwide.
* Services are deployed per region, but some (e.g., **Azure Front Door**, **Azure AD**) are **global services** not tied to one region.

### Tenants

* Every organization gets an **Azure AD tenant** (Entra ID).
* The tenant acts as the **root identity boundary** for users, apps, and devices.

### Resource Groups

* Logical containers for grouping Azure resources (VMs, VNets, storage).
* Each resource belongs to one subscription + one resource group.

### Service Tags

* Microsoft publishes **service tags** = logical groups of IP ranges for services.
* Examples: `AzureActiveDirectory`, `Storage`, `Sql`, `AzureFrontDoor.MicrosoftSecurity`.
* Used in NSGs, Azure Firewall, and third-party firewalls to simplify allow rules.
* Tags are updated weekly by Microsoft (JSON feed).


- JSON Format Example – Service Tag Entry

Microsoft publishes **Azure IP Ranges & Service Tags** as a JSON file, updated weekly.
Each service tag is defined in a block with consistent fields:

```json
{
  "name": "AzureFrontDoor.MicrosoftSecurity",
  "id": "AzureFrontDoor.MicrosoftSecurity",
  "properties": {
    "changeNumber": 1,
    "region": "",
    "regionId": 0,
    "platform": "Azure",
    "systemService": "AzureFrontDoor",
    "addressPrefixes": [
      "13.107.219.0/24",
      "13.107.227.0/24",
      "13.107.228.0/23",
      "150.171.97.0/24",
      "2620:1ec:40::/48",
      "2620:1ec:49::/48",
      "2620:1ec:4a::/47"
    ],
    "networkFeatures": [
      "NSG",
      "API",
      "UDR",
      "FW"
    ]
  }
}
```

### Field Breakdown

* **`name` / `id`** → Service tag identifier (used in Azure Firewall/NSG rules).
* **`changeNumber`** → Incremented whenever Microsoft changes the ranges.
* **`region` / `regionId`** → If blank, this service tag is **global** (applies to all regions).
* **`platform`** → Which cloud the tag belongs to (`Azure`, `AzureChinaCloud`, `AzureGovernment`).
* **`systemService`** → Related Azure service (e.g., `AzureFrontDoor`, `Storage`, `Sql`).
* **`addressPrefixes`** → The list of IP ranges (IPv4 + IPv6) belonging to the service.
* **`networkFeatures`** → Where the tag can be used:

  * `NSG` (Network Security Group)
  * `API` (queried via Azure API/PowerShell/CLI)
  * `UDR` (User Defined Routes)
  * `FW` (Azure Firewall)




## Networking in Azure Public Cloud

### Virtual Network (VNet)

* Isolation boundary for Azure workloads.
* Subnets, NSGs (firewall rules), and route tables define traffic.

### Outbound Access

* Azure services (like Intune, AAD, or Key Vault) often require outbound internet.
* Microsoft publishes required IPs/hostnames under **service tags**.
* Example: `Intune` service tag lists Intune MDM endpoints.

### Azure Front Door (AFD)

* Microsoft’s **global edge network** for optimizing delivery.
* Provides load balancing, TLS termination, and WAF (Web Application Firewall).
* Now used by Intune for device management traffic (`AzureFrontDoor.MicrosoftSecurity`).

---

## Public Cloud vs. Government Cloud

* **Public Cloud** = standard global Azure (commercial).
* **Government Clouds (GCC, GCC High, DoD)** = separate environments with restricted endpoints and compliance requirements.
* Microsoft publishes separate IP/service tag lists for each.

---


## Example: Intune on Azure Public Cloud

* Intune endpoints live in the **Public Cloud** service tag list.
* As of Dec 2025, Intune also leverages **Azure Front Door** for traffic.
* Required service tags:

  * `Intune` (existing)
  * `AzureFrontDoor.MicrosoftSecurity` (new, additive)


**What would be done if outbound 443 is restricted:**

* Firewall/security policies would be updated to allow outbound **TCP 443** to the `AzureFrontDoor.MicrosoftSecurity` service tag (or the equivalent CIDRs from the [Azure IP Ranges & Service Tags JSON](https://www.microsoft.com/en-us/download/details.aspx?id=56519)).
* Existing Intune endpoint rules would be left in place.
* SSL inspection would be bypassed for `*.manage.microsoft.com` and `*.dm.microsoft.com`.

### Architecture diagram

```
                          ┌───────────────────────────┐
                          │     Intune Service        │
                          │  (*.manage.microsoft.com) │
                          │  (*.dm.microsoft.com)     │
                          └──────────────┬────────────┘
                                         │
                                         │
                          ┌──────────────▼──────────────┐
                          │  Azure Front Door (AFD)     │
                          │  Service Tag:               │
                          │  AzureFrontDoor.Microsoft.S │  
                          │  - Global Edge Nodes        │
                          │  - Backed by many IP ranges │
                          └──────────────┬──────────────┘
                                         │
                                         │  DNS Resolution
                                         ▼
                            ┌─────────────────────┐
                            │   Public IP Prefixes │
                            │ (JSON weekly export) │
                            └─────────────────────┘
                                         │
                                         ▼
────────────────────────────────────────────────────────────
                 Corporate Firewall / Security Edge
────────────────────────────────────────────────────────────
      │
      │  Outbound TCP 443
      ▼
┌───────────────┐
│   Endpoints   │
│ (User Device) │
└───────────────┘
```




## Notes

* Public Cloud JSON with IP ranges is updated **weekly**:
  [Azure IP Ranges & Service Tags – Public Cloud](https://www.microsoft.com/en-us/download/details.aspx?id=56519)
* Service tags can be queried via **PowerShell**:

  ```powershell
  Get-AzNetworkServiceTag -Location "westus"
  ```
* Most enterprises use service tags rather than hardcoding IPs.
* Global services (AAD, Front Door, Intune) will usually show `"region": ""` in the JSON (since they’re not tied to one region).
