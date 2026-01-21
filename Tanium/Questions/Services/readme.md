# Tanium Service Monitoring – Query Patterns (Generalized)

This note documents **standard Tanium Interact query patterns** for discovering **running** and **stopped** Windows services across endpoints. All examples are generalized using a placeholder service name: `service-name`.

Use these patterns to:

* Discover what services exist in your environment
* Identify which machines are running a specific service
* Detect service outages by finding stopped services
* Scope queries to specific machine naming conventions (optional)

---

## 1. Discover All Running Services (Environment-Wide)

**Purpose:**
List all running services across all endpoints. Use this to discover valid service names before building targeted queries.

```sql
Get Computer Name and Running Service from all machines
```

---

## 2. Find Machines Running a Specific Service

**Purpose:**
Identify all machines where a specific service is currently running.

```sql
Get Computer Name and Running Service
from all machines
with Running Service contains "service-name"
```

**Notes:**

* `contains` is preferred over `equals` for resiliency (handles display name variations)
* Useful for confirming service deployment or coverage

---

## 3. Find Machines Where a Specific Service Is Stopped

**Purpose:**
Detect service outages or unhealthy endpoints by locating machines where a service exists but is stopped.

```sql
Get Computer Name and Stopped Service
from all machines
with Stopped Service contains "service-name"
```

**Notes:**

* Best used for monitoring and alerting use cases
* Can be converted into Tanium alerts with Tanium connect module 

---

## 4. Monitor Multiple Related Services (Grouped Services)

**Purpose:**
Check the status of multiple related services (for example, app + web + agent components).

### Running

```sql
Get Computer Name and Running Service
from all machines
with (
  Running Service contains "service-name-1"
  or Running Service contains "service-name-2"
)
```

### Stopped

```sql
Get Computer Name and Stopped Service
from all machines
with (
  Stopped Service contains "service-name-1"
  or Stopped Service contains "service-name-2"
)
```

---

## 5. Scope Service Monitoring to a Subset of Machines (Optional)

**Purpose:**
Limit service results to machines matching a naming convention (for example: servers, app tiers, roles).

```sql
Get Computer Name and Stopped Service
from all machines
with
  Computer Name contains "name-pattern"
  and Stopped Service contains "service-name"
```

**Examples of `name-pattern`:**

* `srv-`
* `app-`
* `print-`

---

## 6. Running vs Stopped – Conceptual Difference

* **Running Service**: Services currently active on the endpoint
* **Stopped Service**: Services installed but not running

Use **Running Service** to confirm health and deployment.
Use **Stopped Service** to detect failures, crashes, or misconfigurations.

---

## Best Practices

* Always start with **"Get Computer Name and Running Service from all machines"** to discover exact service names
* Prefer `contains` over `equals`
* Separate running vs stopped queries for clarity and alerting
* Use grouped queries for applications with multiple services
* Add name-based scoping only when needed

---

**Placeholder Legend**

* `service-name` → Replace with the actual Windows service display name
* `name-pattern` → Replace with your endpoint naming convention

