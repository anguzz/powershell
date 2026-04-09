# Azure networking features notes

The following are my notes on azure networking features. Most of it is taken directly from azure documentation or shortened by LLMs.

https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview

# Azure vnets

- virtual nets are is the network that faciliates azure Communication of
1) Azure resources with the internet and  
2) between Azure resources 
3) and with on-premises resources.



# Azure peering

Azure Virtual Network peering enables you to seamlessly connect two or more virtual networks in Azure, making them appear as one for connectivity purposes.

Azure supports the following types of peering:

Virtual network peering: Connect virtual networks within the same Azure region.

Global virtual network peering: Connect virtual networks across Azure regions.

The network latency between virtual machines in peered virtual networks in the same region is the same as the latency within a single virtual network. 

https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering?tabs=peering-portal

# Azure routing methods

 Azure automatically creates a route table for each subnet within an Azure virtual network and adds system default routes to the table. Understanding traffic routing helps you optimize connectivity and troubleshoot network issues in your Azure environment. 

- systems routes: Azure automatically creates system routes and assigns the routes to each subnet in a virtual network. 

- default system routes: Each route includes an address prefix and next hop type. Azure uses the route with the matching address prefix when traffic exits a subnet toward an IP address. Do not modify

virutal nets: Azure virtual networks automatically route traffic between address ranges and subnets within the VNet. Azure creates routes for each VNet address range, and no route tables or gateways are required for subnet‑to‑subnet traffic. Subnets are implicitly covered by the VNet’s address space.


Custom routes
You create custom routes by either creating user-defined routes (UDRs) or exchanging BGP routes between your on-premises network gateway and an Azure virtual network gateway.

user defined routes: dont modify the defauult routes create custom or user defined routes to override default routes

https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview
https://learn.microsoft.com/en-us/azure/virtual-network/diagnose-network-routing-problem


# Express routes
- ExpressRoute lets you extend your on-premises networks into the Microsoft cloud over a private connection with the help of a connectivity provider. With ExpressRoute, you can establish connections to Microsoft cloud services, such as Microsoft Azure and Microsoft 365. Microsoft uses BGP, an industry standard dynamic routing protocol, to exchange routes between your on-premises network, your instances in Azure, and Microsoft public addresses. We establish multiple BGP sessions with your network for different traffic profiles. 


https://learn.microsoft.com/en-us/azure/expressroute/expressroute-introduction
https://learn.microsoft.com/en-us/azure/expressroute/expressroute-routing
https://learn.microsoft.com/azure/expressroute/expressroute-routing#default-route-behavior




# Private Endpoints
A private endpoint is a network interface that uses a private IP address from your virtual network. This network interface connects you privately and securely to a service that's powered by Azure Private Link. By enabling a private endpoint, you're bringing the service into your virtual network. Could be VM, Store, Database, etc



https://learn.microsoft.com/azure/private-link/private-endpoint-overview


## Azure Firewall SKUs – Summary

### Azure Firewall Basic

*   Designed for **small and medium-sized businesses (SMBs)**
*   Provides **essential firewall protection** at lower cost
*   **Key limitations**:
    *   Threat Intelligence: **Alert mode only**
    *   **Fixed scale** (2 backend VM instances)
    *   Recommended throughput: **\~250 Mbps**
*   Best suited for **small / low-throughput environments**

***

### Azure Firewall Standard

*   Provides **Layer 3–Layer 7 (L3–L7) filtering**
*   Uses **Microsoft Threat Intelligence feeds**
*   Capabilities:
    *   Alerts on and blocks traffic to/from **known malicious IPs and domains**
    *   **Real-time updates** for emerging threats
*   Suitable for **most enterprise workloads**

***

### Azure Firewall Premium

*   Includes **all Standard features**
*   Adds **advanced security capabilities**:
    *   **Signature-based IDPS** (Intrusion Detection & Prevention System)
    *   Detects malware, phishing, coin mining, trojans, and exploits
    *   Uses **67,000+ signatures** across **50+ categories**
    *   Signatures are **updated in real time**
*   Best for **high-security / regulated environments**

***

## Azure Firewall Manager

*   Centralized management for **multiple Azure Firewalls**
*   Uses **Firewall Policies** to apply:
    *   Network rules
    *   Application rules
    *   Configuration standards
*   Supports:
    *   **Virtual Network firewalls**
    *   **Virtual WAN / Secure Virtual Hub** deployments
*   Secure Virtual Hub simplifies routing using **Virtual WAN route automation**


https://learn.microsoft.com/en-us/azure/firewall/



# Azure Nat Gateway

Azure NAT Gateway is a fully managed and highly resilient Network Address Translation (NAT) service.

. You can use Azure NAT Gateway to let all instances in a subnet connect outbound to the internet while remaining fully private. 

NAT Gateway dynamically allocates SNAT ports to automatically scale outbound connectivity and minimize the risk of SNAT port exhaustion.

Zone-redundant - operates across all availability zones in a region to maintain connectivity during a single zone failure.

https://learn.microsoft.com/azure/virtual-network/nat-gateway/nat-gateway-resource

## Azure firwall vs NAT gateway

- Use Firewall when security requirements exist
 URL / FQDN allow‑listing or deny‑listing
 Blocking known malicious destinations
 Regulatory logging / audit requirements
 TLS inspection (Premium)
 Explicit egress governance (“only these destinations”)

Firewal cost more so if inspecting is not necessary dont add

For example: AVD usage.
If AVD outbound traffic does not need inspection, filtering, or logging → use NAT Gateway
If AVD outbound traffic does need inspection or control → use Azure Firewall


Firewall is for decisions. NAT Gateway is for scale.
If you’re not making decisions on AVD outbound traffic, don’t force it through a firewall.

# Video resources: 

Azure Networking Fundamentals
https://www.youtube.com/watch?v=K8eP7ZCgZpM


Azure Hybrid Connectivity
https://www.youtube.com/watch?v=J2r1ZpQoD0M

