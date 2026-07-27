# CS 107: Firewall Management Foundations

Falcon Firewall Management is a comprehensive solution that provides organizations with advanced security features, centralized management, and real-time monitoring capabilities.

It provides centralized management of the native firewall capabilities built into Windows, macOS, and Linux operating systems.

Instead of managing firewall settings individually on thousands of endpoints, Falcon allows administrators to configure, deploy, and monitor firewall policies from a single Falcon console.

The primary benefit of Falcon Firewall Management is centralized management of native firewalls.

---

# Cross-Platform Firewall Management

Organizations often operate a mix of Windows, macOS, and Linux systems. Falcon Firewall Management allows administrators to create, deploy, and monitor firewall policies from a single console while leveraging platform-specific technologies behind the scenes.

Rather than requiring administrators to learn and manage separate firewall tools for each operating system, Falcon provides a unified policy management experience across supported platforms.

## Platform Technologies

| Platform | Firewall Technology Used by Falcon |
|----------|-----------------------------------|
| Windows | Windows Filtering Platform (WFP) |
| macOS | Network Extensions Framework |
| Linux | Extended Berkeley Packet Filter (eBPF) |

Falcon does **not** rely on traditional operating system firewall management tools such as:

- Windows Firewall
- pf
- iptables
- firewalld

---

# Key Concepts

1. Endpoint firewalls help prevent unauthorized network communications and reduce attack surface.

2. Falcon Firewall Management centrally manages firewall policies across Windows, macOS, and Linux endpoints.

3. Falcon Firewall Management provides centralized policy management while platform-specific firewall technologies enforce traffic decisions on Windows, macOS, and Linux endpoints.

---

# Firewall Rule Creation

Navigate to:

**Endpoint Security → Firewall → Policies**

Use firewall policies to apply rules in your firewall rule groups to hosts.

- Maximum of **100 firewall policies**, including the **Default Policy**

---

# Rule Groups

Navigate to:

**Endpoint Security → Firewall → Rule Groups**

The Rule Groups page allows administrators to create firewall rule groups that logically organize firewall rules.

Once rule groups and rules are created and assigned, they can be used to define traffic that is allowed or blocked.

---

# Policies vs Rule Groups

| Policy | Rule Groups |
|----------|----------|
| Define firewall behavior for assigned endpoints | Organize related firewall rules |

## Examples

### Policies
- Remote Worker Policy
- Server Policy
- Developer Policy

### Rule Groups
- VPN Rules
- Database Rules
- Web Services Rules

---

# Create Firewall Rules

Firewall rules define the network traffic that should be allowed, blocked, or monitored.

Rules can evaluate:

- Direction (Inbound or Outbound)
- Protocol (TCP, UDP, ICMP)
- Ports
- Applications
- IP Addresses
- Network Locations

### Example

Allow outbound HTTPS traffic on TCP port 443.

This rule defines a single traffic behavior but does not yet affect any endpoints.

---

# Organize Rules into Rule Groups

As organizations create more firewall rules, managing them individually becomes difficult.

Rule groups allow administrators to organize related firewall rules into logical collections.

Benefits include:

- Reusable across multiple policies
- Reduced duplication
- Simplified management

---

# Create Firewall Policies

Firewall policies are used to enforce firewall behavior.

Administrators assign one or more rule groups to a policy and configure how remaining traffic should be handled.

A policy can:

- Allow traffic defined by assigned rule groups
- Block traffic defined by assigned rule groups
- Specify how unmatched traffic is handled
- Determine logging and monitoring behavior

## Example: Remote Worker Policy

Includes:

- VPN Rule Group
- Collaboration Tools Rule Group
- Security Controls Rule Group

This policy defines how remote employee endpoints should communicate.

---

# Assign Policies to Host Groups

Policies are deployed through Host Groups.

A Host Group contains endpoints that share similar security requirements.

| Host Group | Typical Systems |
|------------|----------------|
| Corporate Workstations | Employee laptops and desktops |
| Remote Workers | Home-office devices |
| Development Systems | Developer workstations |
| Production Servers | Critical infrastructure |

When a policy is assigned to a Host Group, all members of that Host Group receive the policy.

---

# Enable and Deploy the Policy

Once configured, the policy must be enabled.

After enabling:

- Falcon distributes the policy configuration
- The Falcon Sensor receives the policy
- The endpoint firewall enforces the configured rules
- Activity data is reported back to Falcon

This centralized deployment process ensures consistent firewall behavior across managed endpoints.

---

# Firewall Activity

Navigate to:

**Endpoint Security → Firewall → Activity**

Use the Activity page to review firewall events, policy actions, and traffic enforcement activity.

---

# Network Locations

Navigate to:

**Endpoint Security → Firewall → Network Locations**

Network Locations allow organizations to apply different firewall behavior depending on where the endpoint is connected.

Examples:

- More permissive firewall policy when connected to the corporate network
- More restrictive firewall policy when connected to home or public networks

---

# How Falcon Evaluates Network Location Conditions

## OR Logic Within a Condition

If a condition contains multiple values, only one value must match.

### Example: DHCP Server Addresses

- 10.35.0.1
- 10.0.0.1
- 10.0.0.2

Evaluation:

```sql
10.35.0.1
OR
10.0.0.1
OR
10.0.0.2
```

If any one value matches, the condition is satisfied.

***

## AND Logic Between Conditions

Different condition types are evaluated using AND logic.

For the Network Location to match, every condition category must be satisfied.

### Example Configuration

**Connection Type**

* Wired

**DHCP Server Address**

* 10.35.0.1
* 10.0.0.1
* 10.0.0.2

**Gateway IP Address**

* 192.168.1.1

Evaluation:

```sql
(Connection Type = Wired)

AND

(DHCP Server =
 10.35.0.1 OR
 10.0.0.1 OR
 10.0.0.2)

AND

(Gateway IP = 192.168.1.1)
```

The endpoint must:

* Use a wired connection
* Match at least one DHCP server listed
* Match the specified gateway IP address

If any condition group fails, the Network Location does not match.

***

# Why Use Multiple Values?

Organizations often have multiple network components representing the same trusted environment.

Examples include:

* Multiple DHCP servers
* Multiple gateways
* Several IP address ranges

Instead of creating separate Network Locations for each component, administrators can include all valid values within a single condition.

This simplifies configuration and makes ongoing management easier.

***

# Firewall Management Workflow Summary

1. Create Firewall Rules
2. Organize Rules into Rule Groups
3. Create Firewall Policies
4. Assign Policies to Host Groups
5. Enable and Deploy the Policy
6. Monitor Activity and Adjust as Needed

```

