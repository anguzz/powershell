
#  SCEP and CA Certificates

## Overview
SCEP (Simple Certificate Enrollment Protocol) enables devices to automatically request and install certificates from an internal CA, often used for secure Wi-Fi (EAP-TLS) or VPN authentication in Intune-managed environments.

---

##  SCEP Certificate

- Issued **per device or user** to prove identity
- Common use: Wi-Fi (EAP-TLS), VPN, app access
- Installed via:
  ```
  Intune > Device Configuration > SCEP Certificate profile
  ```

**Contains:**
- Device/User identity (CN/SAN)
- Signed by internal CA

---

##  CA Certificate

- The **root or intermediate certificate** that signs SCEP certificates
- Required to **trust** the issued SCEP certs
- Installed via:
  ```
  Intune > Device Configuration > Trusted Certificate profile
  ```

**Used by:**
- Devices (to trust the CA)
- Wi-Fi/VPN servers (to validate client certs)

---

##  Notes

- **Both SCEP + CA certs are needed** for EAP-TLS to work.
- The **SCEP cert proves identity**, the **CA cert proves trust**.
- Devices can’t validate or present certs correctly without the CA chain.
- View installed certs:
  ```powershell
  certlm.msc  # for Local Machine store
  ```
- Logs for SCEP deployment:
  ```
  C:\Windows\Logs\DeviceManagement\*.log
  ```

---
