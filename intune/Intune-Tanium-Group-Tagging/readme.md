# **Tanium Group Tagging via Intune Remediation/Application**

This process applies **group-specific registry tags** to Windows devices so Tanium can identify which **Entra ID user group** a signed-in user belongs to.

The script **does not query Entra**.
Instead, each group has a **1:1 mapping** between an Entra group and a registry tag.
Intune pushes the correct tag to the device based on group assignment.

This enables Tanium to classify devices in a **clean, predictable, and fully Intune-driven** way.

You can deploy the tagging script as:

* An Intune remediation (scheduled or on-demand)
* A Win32 application assigned to user groups
* A recurring tag-enforcement task

---

## **Overview**

Assumes:

* An **Entra ID security group** is created
* A **corresponding registry tag name** is mapped to that group
* An **Intune remediation or Win32 deployment** is targeted to that user group

When a user in that group signs into a device, the script runs as **SYSTEM** and writes:

```
HKLM:\SOFTWARE\Tanium\Tanium Client\Sensor Data\Tags\<TagName>
```

Tanium sensors then use this value for targeting, filtering, deployments, and reporting.

---

## **How the Tagging Flow Works**

1. **Create an Entra group** that represents the user group
2. **Assign users** to that group
3. **Clone the remediation/Win32 script** and update `$tagName`
4. **Assign the script** to the corresponding Entra user group
5. Upon sign-in, Intune runs the script as SYSTEM and writes the registry tag

This creates a stable and predictable relationship between:

* User group membership
* The device the user authenticates on
* The tags Tanium detects
* How endpoints get categorized

---

## **Script Behavior**

The script:

* Ensures the tag path exists:

  ```
  HKLM:\SOFTWARE\Tanium\Tanium Client\Sensor Data\Tags\
  ```

* Creates a registry value named after the group’s tag

* Writes `"True"` (REG_SZ)

* Is **idempotent** — safe to run repeatedly

* Can be targeted to **user groups** because execution occurs under SYSTEM

To add more groups, simply **duplicate the script and update `$tagName`**.

---

## Intune deployment
Ensure this is deployed in 64 bit powershell if you want it go to `HKEY_LOCAL_MACHINE\SOFTWARE\Tanium\Tanium Client\Sensor Data\Tags`
otherwise it will install to the WOW6432Node at `HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags`

- install command

`%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\install.ps1`

- uninstall command

`%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\uninstall.ps1`


# **Tanium Query Usage**

Valid queries for reading tags in Tanium:

---

### **Check if a specific tag exists**

```shell
Get Registry Key Value Exists[HKLM:\SOFTWARE\Tanium\Tanium Client\Sensor Data\Tags\<TagName>] 
from all entities with Is Windows equals True
```

---

### **Return computers with a given tag**

```shell
Get Computer Name 
from all entities 
with Registry Key Value Exists[HKLM:\SOFTWARE\Tanium\Tanium Client\Sensor Data\Tags\, <TagName>] equals True
```

---

### **Return everything under HKLM:\SOFTWARE\Tanium**

```shell
Get Registry Key Subkeys[HKLM\SOFTWARE\Tanium]
```

---

### **Reference**

Tanium KB:
[https://help.tanium.com/bundle/z-kb-articles-salesforce/page/kA00e000000TbgbCAC.html](https://help.tanium.com/bundle/z-kb-articles-salesforce/page/kA00e000000TbgbCAC.html)

---

## **Notes**

* **Do not target multiple tagging scripts to the same user group.**
* If a user belongs to multiple groups, **multiple tags will be written** (expected behavior).
* Script must run as **SYSTEM** to write to HKLM.
* Tanium sensors can fully classify devices based on these tags.
* Tags are **additive**, not mutually exclusive.
* Devices keep tags until explicitly removed via an uninstall/cleanup script.

---

# **Tagging Flow Diagram (With Platform Labels)**

```shell
+--------------------+
|     Entra ID       |
+--------------------+
          │
          ▼
+------------------------------+
| User is member of Entra Group |
+------------------------------+

          │
          ▼

+--------------------+
|       Intune       |
+--------------------+
          │
          ▼
+-------------------------------------------+
| Remediation / Win32 App assigned to group |
+-------------------------------------------+

          │
          ▼

+--------------------+
|      Device        |
+--------------------+
          │
          ▼
+--------------------------------------------------------------+
| Script runs as SYSTEM and writes registry tag:               |
| HKLM\SOFTWARE\Tanium\Tanium Client\Sensor Data\Tags\<Tag>    |
+--------------------------------------------------------------+

          │
          ▼

+--------------------+
|      Tanium        |
+--------------------+
          │
          ▼
+--------------------------------------------------------------+
| Sensors detect tag → dynamic grouping, reporting, targeting  |
+--------------------------------------------------------------+
```

