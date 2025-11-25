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

When a user in that group signs into a device, the script runs as **SYSTEM** and writes to:

```
HKLM:\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags\<TagName>
```

Tanium sensors then use this value for targeting, filtering, deployments, and reporting.

---

## **How the Tagging Flow Works**

1. Create an Entra group
2. Add users to that group
3. Duplicate the remediation/Win32 script & set `$tagName`
4. Assign the script to the matching Entra user group
5. Script runs as SYSTEM → writes tag to WOW6432Node

This creates a stable relationship between:

* User identity → Device → Registry tag → Tanium classification

---

## **Script Behavior**

The script performs the following:

* Ensures the WOW6432Node path exists:

```
HKLM:\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags\
```

* Creates a registry value named after the group’s tag
* Writes a timestamp using value using powershell as a string (REG_SZ)
* Is **safe to run repeatedly (idempotent)**
* Works when targeted to **user groups**, since execution is under SYSTEM

To add new groups, just **clone the script and change `$tagName`**.

---

# **Intune Deployment**

Since Tanium runs as a **32-bit service**, you MUST target the 32-bit registry hive.
To do this reliably in Intune, always run the script with **SysNative path** to force 64-bit PowerShell into 32-bit registry redirection.

Other tanium tags that get created through tanium also install to this hive.


### **Install Command**

```
powershell -ex bypass -file install.ps1

```

### **Uninstall Command**

```
powershell -ex bypass -file uninstall.ps1
```

### **Registry Location Used**

```
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags
```

---

# **Tanium Query Usage**


- `Get Computer Name from all entities with Registry Key Value Exists[HKLM\SOFTWARE\Tanium\Tags,<tag-name>] equals True` gives you a listing of all machine names with the tag in single list


- `Get Registry Key Value Exists[HKLM\SOFTWARE\Tanium\Tags,<tag-name>] from all entities with Is Windows equals True` shows all true and false machines with tag

---

### **Return everything under WOW6432Node Tanium**

```
Get Registry Key Subkeys[HKLM\SOFTWARE\WOW6432Node\Tanium]
```

---

### **Reference**

Tanium KB:
[https://help.tanium.com/bundle/z-kb-articles-salesforce/page/kA00e000000TbgbCAC.html](https://help.tanium.com/bundle/z-kb-articles-salesforce/page/kA00e000000TbgbCAC.html)

Enhanced tagging:
[https://help.tanium.com/bundle/EnhTagsDoc/page/KA/EnhTagsDoc/EnhTagsDoc.htm](https://help.tanium.com/bundle/EnhTagsDoc/page/KA/EnhTagsDoc/EnhTagsDoc.htm)

---

## **Notes**

* Do **not** target multiple tagging scripts to the same user group
* If a user belongs to multiple groups, **multiple tags will be written**
* Script must run as **SYSTEM**
* Tags persist until removed by a cleanup script
* Tags are additive and safe for dynamic grouping

---

# **Tagging Flow Diagram (Updated to WOW6432Node)**

```
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
+--------------------------------------------------------------------------+
| Script runs as SYSTEM and writes registry tag:                           |
| HKLM\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags\<Tag>    |
+--------------------------------------------------------------------------+

          │
          ▼

+--------------------+
|      Tanium        |
+--------------------+
          │
          ▼
+--------------------------------------------------------------------------+
| Sensors detect tag → dynamic grouping, reporting, targeting              |
+--------------------------------------------------------------------------+
```

