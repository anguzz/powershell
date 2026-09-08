# Microsoft Defender XDR - Automated Response Exclusions


Attack Disruption is a Microsoft managed response capability that uses built-in analytics and AI driven attack correlation to determine when automated containment actions are required. Organizations cannot create custom Attack Disruption rules or define custom containment logic.
 
 However, organizations can influence behavior through:
- Identity exclusions
- Device exclusions
- IP/subnet exclusions
- Policy application exclusions (where available)

These controls allow organizations to prevent specific automated response actions while retaining Defender visibility and detections.

## Location

In Microsoft Defender XDR, go to:

```text
System > Settings > Automated response > Identities or Devices
```

- **Identities**: Exclude specific user identities from supported automated identity response actions.
- **Devices**: Exclude devices from automated response actions using device groups, IP addresses or subnets, or policy application exclusions where available.

---

## Use Case

When authorized security tools, penetration tests, red team exercises, vulnerability scanners, or attack simulation platforms trigger Defender XDR containment actions, an **Automatic Attack Disruption exclusion** may be more appropriate than an IOC allow indicator.

Defender XDR supports exclusions for both **identities and devices**, depending on which automated response actions need to be prevented.

### Goal

- Continue collecting telemetry
- Continue generating alerts and incidents
- Preserve detection and investigation visibility
- Prevent selected automated containment actions

Use the narrowest exclusion scope that meets the authorized testing or operational requirement.

---

## Available Exclusion Approaches

### Identity exclusions

Identity exclusions can prevent selected user identities from being automatically contained or disabled by Automatic Attack Disruption.

### Device exclusions

Device exclusion approaches can include:

- Device groups
- IP addresses or subnets
- Policy application exclusions

An IP exclusion is useful when authorized activity consistently originates from a known scanner, testing runner, or security appliance.

---

## What Automatic Attack Disruption Can Do

Automatic Attack Disruption is designed to contain a high-confidence active attack by restricting affected identities and devices.

### Identity actions

- Contain a user
- Disable a user account
- Perform other supported identity containment actions

### Device actions

- Isolate a device
- Contain a device
- Contain an unmanaged device
- Limit lateral movement

---

## Defender Feature Comparison

| Feature | Purpose |
|---|---|
| IOC Allow/Exclude | Configure handling for indicators such as IP addresses, domains, files, or certificates |
| Antivirus Exclusions | Exclude specified files, folders, extensions, or processes from Microsoft Defender Antivirus scanning |
| Automated Investigation and Remediation (AIR) | Investigate alerts and apply supported remediation actions |
| Automatic Attack Disruption | Automatically contain identities and devices during a high-confidence active attack |

---

## How to Confirm Attack Disruption Took Action

### Incident Activities

Open the incident and review:

```text
Incident > Activities
```

Look for response entries such as:

- Isolate Device
- Contain Device
- Contain User
- Uncontain User

Verify the activity details show:

```text
Performed by: Attack Disruption
Trigger: Automated
```

### Action Center

Review the Defender XDR Action Center for:

- Response action
- Target identity or device
- Trigger source
- Performed by
- Status

---

## Common Signs of an Attack Disruption Incident

- The incident title includes `attack disruption`
- The incident includes an **Attack Disruption** tag
- A banner states that Attack Disruption initiated response actions
- The Activities page shows actions performed by **Attack Disruption** with an **Automated** trigger

---

## Key Takeaway

If Defender XDR automatically isolates or contains a device, or contains or disables an identity during authorized activity, review **Automatic Attack Disruption exclusions** before using an IOC allow indicator or antivirus exclusion.

Choose the exclusion area that matches the affected asset:

- Use an **identity exclusion** when the concern is automated containment or disablement of a specific user identity.
- Use a **device exclusion** when the concern is automated device response, including activity associated with an approved IP address, subnet, or device group.

These exclusions are intended to prevent applicable automated containment actions. They are not alert-tuning rules, IOC allow indicators, or antivirus exclusions.

### Microsoft Learn

- Automatic attack disruption in Microsoft Defender XDR

https://learn.microsoft.com/en-us/defender-xdr/automatic-attack-disruption

 
- Configure automatic attack disruption in Microsoft Defender XDR
https://learn.microsoft.com/en-us/defender-xdr/configure-attack-disruption

 
- Exclude assets from automated responses in automatic attack disruption
https://learn.microsoft.com/en-us/defender-xdr/automatic-attack-disruption-exclusions