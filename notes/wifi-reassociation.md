
# Windows WLAN Scan Behavior & Wi-Fi Reassociation Notes

## Background

The Network team has observed wireless performance degradation across several branch locations. Access points are being impacted by **frequent invalid reassociation attempts**, creating excess wireless noise and degrading overall AP performance.

Investigation shows that when a Windows client is already connected to **Guest** (or another non-Employee SSID), it will still repeatedly attempt to associate with the **Employee** SSID. Because Windows cannot forcefully disconnect from the currently active network, these association attempts fail and retry continuously.

This behavior results in:

- Continuous background scanning and reassociation attempts  
- Increased load on access points  
- Degraded wireless performance at affected sites  

Meraki has also indicated that **onboarding failures** are preventing some devices from successfully connecting to the Employee SSID, further amplifying the reassociation behavior.

The Network team asked whether Windows, GPO, or Intune controls exist to:

- Suppress reassociation attempts when a user already has working internet access  
- Force a disconnect from Guest to allow association to Employee  
- Introduce a retry timeout or backoff interval for reassociation attempts  


Below are some possible solutions I looked at during researching endpoint side fixes.

## Roaming Aggressiveness (Why It Falls Short)

Windows roaming aggressiveness controls how readily a client scans for and evaluates alternative access points:

```

Lowest       → Do not roam unless the connection is very poor
Medium-Low   → Limited roaming
Medium       → Balanced roaming (default)
Medium-High  → More frequent roaming
Highest      → Continuous evaluation

```

Lowering roaming aggressiveness was considered as a potential mitigation to reduce background scan activity.

In practice, this approach has significant limitations:

- There is no consistent or clean way to enforce roaming aggressiveness via Intune  
- Changes are driver-specific and often require custom scripts  
- Guest and Employee SSIDs share the same roaming context (`rsxid`)

Because Windows treats Guest and Employee as related networks within the same roaming domain, reducing roaming aggressiveness alone does **not** reliably stop reassociation attempts.

This makes roaming aggressiveness **unsuitable as a primary or long-term mitigation**.


## Client-Side Wi-Fi Profile Settings

Within the Employee Wi-Fi profile, Windows exposes several options:

- Connect automatically when this network is in range  
- Connect even if the network is not broadcasting  
- Look for other wireless networks while connected  

Disabling *“look for other wireless networks while connected”* may slightly reduce scan behavior. However:

- Enforcement via GPO or Intune is inconsistent  
- Actual behavior varies by NIC driver and vendor  

These settings can be treated as **supplemental tuning**, but they are not reliable enough to act as a core control.


## Why Roaming-Only Controls Don’t Work

Guest and Employee SSIDs appear to share internal roaming identifiers:

- **rsxid** — roaming / reassociation context  
- **rsxod** — roaming operation or decision  

Because the same `rsxid` is reused across both SSIDs, Windows continues to evaluate them as roaming candidates even when already connected. This behavior is **working as designed**, which limits how effective roaming-based mitigations can be.


## WLAN Scan Mode 

The most likely effective endpoint side control is **WLAN Scan Mode**.

- **Policy:** WLAN Scan Mode  
- **CSP Path:** `./Device/Vendor/MSFT/Policy/Config/Wifi/WLANScanMode`  
- **Scope:** Device  
- **Values:** `0–500`  

Value meaning:

- `0` → Default OS / vendor behavior  
- `100` → Normal scan frequency  
- `500` → Lowest scan frequency (maximum backoff)  

### What This Actually Controls

WLAN Scan Mode governs **how aggressively Windows performs background Wi-Fi scans while already connected**.

It does **not**:
- Change roaming thresholds  
- Modify SSID priority  
- Affect authentication behavior  

It **does**:
- Reduce scan frequency  
- Decrease probe and reassociation traffic  
- Lower AP load from connected clients  

This aligns most closely with the request to introduce a **retry or backoff interval** for reassociation attempts.

### Recommended Fix

Set **WLAN Scan Mode = 500**.

This meaningfully reduces reassociation noise without forcing disconnects or negatively impacting user connectivity.


## WLAN Media Cost 

WLAN Media Cost influences how Windows classifies a network’s “cost”: Because of this it was considered but not used due to possible side effects.(use carefully)

- Unrestricted (default)  
- Fixed  
- Variable  

Windows uses this signal to influence preference decisions and background activity.

A potential use case is marking **Guest** as Fixed or Variable while keeping **Employee** as Unrestricted. This can bias Windows toward Employee when choosing between networks.

However:

- It does not reduce scan frequency  
- It does not stop reassociation retries  
- It can impact Windows Update and background services  

This should only be used as a **secondary signal**, not a primary mitigation.


## Takeaways

- **WLAN Scan Mode** is the most likely effective endpoint side control for this issue  
- Roaming aggressiveness and SSID properties offer limited, inconsistent benefit  
- Media Cost can influence preference but carries side effects  
- Full resolution may still require **network-side changes**, especially if onboarding failures persist  


## Referenced docs

* Microsoft Wi-Fi auto-connection priority
  [https://learn.microsoft.com/en-us/answers/questions/4306827/wi-fi-auto-connection-priority](https://learn.microsoft.com/en-us/answers/questions/4306827/wi-fi-auto-connection-priority)

* Microsoft Intune Windows Wi-Fi settings
  [https://learn.microsoft.com/en-us/intune/intune-service/configuration/wi-fi-settings-windows](https://learn.microsoft.com/en-us/intune/intune-service/configuration/wi-fi-settings-windows)

* Windows roaming aggressiveness overview
  [https://www.thewindowsclub.com/wifi-roaming-sensitivity-aggressiveness](https://www.thewindowsclub.com/wifi-roaming-sensitivity-aggressiveness)

* Meraki 802.11 association process explained
  [https://documentation.meraki.com/Wireless/Design_and_Configure/Architecture_and_Best_Practices/802.11_Association_Process_Explained](https://documentation.meraki.com/Wireless/Design_and_Configure/Architecture_and_Best_Practices/802.11_Association_Process_Explained)

* General Windows roaming behavior
  [https://www.makeuseof.com/windows-roaming-aggressiveness-guide/](https://www.makeuseof.com/windows-roaming-aggressiveness-guide/)

* Microsoft WLAN Scan mode 
  [https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-wifi?WT.mc_id=Portal-fx#wlanscanmode](https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-wifi?WT.mc_id=Portal-fx#wlanscanmode)


