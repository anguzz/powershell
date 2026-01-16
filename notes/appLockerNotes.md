# Overview

Application discovery performed via Tanium has identified a growing presence of greyware and OEM bloatware across endpoints. Examples include **Shift Browser**, **OneLaunch**, **AVG Secure Browser**, and vendor utilities such as **Dell SupportAssist**, which have recently contributed to increased disk usage and operational overhead.

These applications typically fall into the categories of **Potentially Unwanted Applications (PUAs)**, adware, trackware, riskware, and bloatware. While not always classified as malware, they frequently introduce undesirable behaviors, degrade system performance, raise privacy concerns, and increase support and remediation effort.

In many cases, CrowdStrike and other EDR platforms do not flag these applications because they fall outside traditional malware classifications. To address this gap, a **custom, environment-specific execution control strategy** is being implemented using **Intune-delivered AppLocker policies**, with a secondary safeguard using Intune’s **“Don’t run specified Windows applications”** policy to provide defense in depth.

---

# Evaluated Blocking Methods

### Attack Surface Reduction (ASR)

ASR rules can complement execution controls but are not sufficient on their own.

* ASR exclusions only exempt specific executables or paths from **ASR enforcement**
* They do **not** affect AppLocker, Defender AV exclusions, or general execution control
* Intended for narrowly scoped, known-good software
* Used sparingly to avoid weakening exploit protection

### App Control for Business (Managed Installer)

App Control for Business was evaluated and ruled out for this use case.

* Requires software to be installed via **managed installers**
* Limits installation sources and workflows
* Does not provide explicit allow/deny guarantees

> “Since managed installer is a heuristic-based mechanism, it doesn't provide the same security guarantees as explicit allow or deny rules do. Managed installer is best suited where users operate as standard user, and where all software is deployed and installed by a software distribution solution such as MEMCM.”

Given the prevalence of user-initiated installers and self-updating applications, this approach was deemed too restrictive and operationally risky.

---

# Chosen Strategy

The selected approach combines **preventive execution controls** with **reactive cleanup**:

* Block execution from common user-writable locations frequently abused by PUAs
* Explicitly deny known greyware paths and binaries
* Remove existing greyware via scripted remediation
* Validate changes through phased ring-based deployment

This strategy balances security enforcement with operational stability and aligns with observed attack patterns.

---

# Threat Model Reference

**MITRE ATT&CK: T1204 – User Execution**

**Observed execution chain:**

1. User interacts with a document, browser download, archive, or installer
2. Payload is written to a user-writable location
3. Parent process launches a living-off-the-land binary
   (e.g., `powershell`, `cmd`, `mshta`, `rundll32`, `msiexec`, `wscript`)
4. Immediate outbound network activity follows

**High-risk writable locations:**

* `%USERPROFILE%\Downloads`
* `%TEMP%`
* `%APPDATA%\*`
* OneDrive / Teams cache directories
* Office startup folders

This behavior aligns with how many PUAs and initial-access payloads execute.

---

# High-Level Workflow

1. Implement execution blocking at both **user and system-relevant paths**
2. Use Tanium for application discovery

   * Query: `Get installed applications from all entities`
3. Parse results for known greyware and PUAs
4. Maintain a structured blocklist:

   ```
   PUA Display Name – Executable – Default Install Location
   ```
5. Run a generalized uninstall/remediation script to improve software hygiene
6. Prevent re-installation or execution via AppLocker deny rules
7. Validate in ring-based test groups and deploy via Intune (OMA policy)

---

# User-Level Backup Blocklist

**Policy Type:** Settings Catalog
**Setting:** *Don’t run specified Windows applications (User)*

**Purpose:**

* Acts as a secondary control for known user-level executables
* Useful when execution paths are unpredictable but filenames are consistent

**Limitations:**

* Renamed executables can bypass the rule
* Not suitable as a primary enforcement mechanism
* Best used as defense-in-depth

---

# AppLocker Blocking Policies

## 1. Block Execution from Downloads

* **Executable Rule**

  * Name: Block executables in Downloads
  * Path: `%OSDRIVE%\Users\*\Downloads\*`

* **Windows Installer Rule**

  * Name: Block MSI in Downloads
  * Path: `%OSDRIVE%\Users\*\Downloads\*`

* **Script Rule**

  * Name: Block PowerShell and scripts in Downloads
  * Path: `%OSDRIVE%\Users\*\Downloads\*`

---

## 2. Block Execution from AppData

* **Executable Rule**

  * Name: Block executables in AppData
  * Path: `%OSDRIVE%\Users\*\AppData\*`

* **Windows Installer Rule**

  * Name: Block MSI in AppData
  * Path: `%OSDRIVE%\Users\*\AppData\*`

* **Script Rule**

  * Name: Block PowerShell and scripts in AppData
  * Path: `%OSDRIVE%\Users\*\AppData\*`

---

## 3. Block Execution from Temp

* **Executable Rule**

  * Name: Block executables in Temp
  * Path: `%OSDRIVE%\Users\*\AppData\Local\Temp\*`

* **Windows Installer Rule**

  * Name: Block MSI in Temp
  * Path: `%OSDRIVE%\Users\*\AppData\Local\Temp\*`

* **Script Rule**

  * Name: Block PowerShell and scripts in Temp
  * Path: `%OSDRIVE%\Users\*\AppData\Local\Temp\*`

---

# Outcome

This approach:

* Reduces PUA execution without relying on signatures
* Aligns with real-world abuse of user-writable paths
* Preserves operational flexibility
* Avoids WDAC breakage and managed installer limitations
* Provides layered enforcement and remediation

---

# References

* MITRE ATT&CK – User Execution (T1204):
  [https://attack.mitre.org/techniques/T1204/](https://attack.mitre.org/techniques/T1204/)
* Blocking applications with Intune (MDM vs MAM):
  [https://blog.ciaops.com/2025/07/02/blocking-applications-on-windows-devices-with-intune-mdm-vs-mam-approaches/](https://blog.ciaops.com/2025/07/02/blocking-applications-on-windows-devices-with-intune-mdm-vs-mam-approaches/)
* Microsoft – App Control for Business (Managed Installer):
  [https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/configure-authorized-apps-deployed-with-a-managed-installer](https://learn.microsoft.com/en-us/windows/security/application-security/application-control/app-control-for-business/design/configure-authorized-apps-deployed-with-a-managed-installer)
* Microsoft Defender – PUA Protection:
  [https://learn.microsoft.com/en-us/defender-endpoint/detect-block-potentially-unwanted-apps-microsoft-defender-antivirus](https://learn.microsoft.com/en-us/defender-endpoint/detect-block-potentially-unwanted-apps-microsoft-defender-antivirus)
* Greyware definition:
  [https://zimperium.com/glossary/grayware](https://zimperium.com/glossary/grayware)
* AppLocker usage examples:
  [https://www.tenforums.com/tutorials/124008-use-applocker-allow-block-executable-files-windows-10-a.html](https://www.tenforums.com/tutorials/124008-use-applocker-allow-block-executable-files-windows-10-a.html)
