# Tanium Installed Application Queries – Generalized Patterns

These queries document **standard Tanium Interact patterns** for identifying **installed applications** across endpoints. All examples use a placeholder application name: `app-name`.

Use these queries to:

* Audit software inventory
* Validate application deployment
* Confirm presence or absence of software
* Retrieve uninstall metadata

---

## 1. Get All Machines and All Installed Applications

**Purpose:**
Return every machine and every installed application, including uninstall strings.

```sql
Get Computer Name and Installed Applications from all machines
```

**Use cases:**

* Full software inventory
* Identify unexpected or shadow IT applications
* Collect uninstall strings for remediation planning

---

## 2. Find Devices with a Specific Microsoft Store App

**Purpose:**
Identify machines with a specific Microsoft Store (UWP) application installed.

```sql
Get Computer Name and Installed Store Apps
having Installed Store Apps:Name contains "app-name"
from all entities
with Installed Store Apps:Name contains "app-name"
```

**Use cases:**

* Validate Store app deployment
* Locate devices with a specific UWP application

---

## 3. Check if an Application Exists (Boolean Result)

**Purpose:**
Return a boolean result indicating whether an application exists on endpoints.

```sql
Get Installed Application Exists[app-name] equals True
from all entities
```

**Use cases:**

* High-level deployment coverage checks
* Compliance validation
* Identifying gaps where software is missing

---

## 4. List All Devices with an Installed Application

**Purpose:**
Return the names of machines where a specific application is installed.

```sql
Get Computer Name
from all entities
with Installed Application Exists[app-name] equals True
```

**Use cases:**

* Targeting endpoints for remediation or upgrades
* Scoping devices for follow-up actions

**Notes:**

* Results may be capped by the Tanium UI (commonly ~100 endpoints)

---

## 5. Installed Applications – Conceptual Notes

* **Installed Applications**: Traditional Win32 / MSI-based software
* **Installed Store Apps**: Microsoft Store / UWP applications
* `Installed Application Exists[...]` returns a **True / False** state

Use **Installed Applications** for inventory and uninstall data.
Use **Installed Application Exists[...]** for fast scoping and compliance logic.

---

## Best Practices

* Start with a full inventory to confirm application naming
* Prefer `Installed Application Exists[...]` for performance and simplicity
* Separate Win32 and Store app queries
* Use existence queries when building tags, alerts, or deployment scopes

---

**Placeholder Legend**

* `app-name` -> Replace with the target application display name
