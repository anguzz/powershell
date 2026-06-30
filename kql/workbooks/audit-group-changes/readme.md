# Azure AD AuditLogs – Group Change Queries

## Description  
These KQL queries track group membership changes (add/remove) in Azure AD AuditLogs. They are built to support workbook parameters so you can quickly search for specific users or devices. These KQL queries are generic and may require customization for your environment. They are designed to run against the Azure AD AuditLogs table.

---

## Files

- `audit-group-changes-user.kql`
- `audit-group-changes-device.kql`

---

## Query Outputs

Each query returns:

- **TimeGenerated**  
- **OperationName**  
- **Group**  
- **AffectedObject**  
- **InitiatedBy**

---

## What the Queries Do

- Pull group membership changes (add/remove)
- Extract target objects (user or device)
- Identify who initiated the change (user or app)
- Normalize fields for easier readability
- Allow filtering via workbook parameters

---

## Workbook Parameter Setup

To make the queries searchable in a workbook:

1. Click **Add > Parameter**
2. Add a parameter:
   - `Username` (for user query)
   - `DeviceName` (for device query)
3. Click **Add > Query**
4. Paste the KQL query

**Important**  
The parameter must be created above the query. If not, the query may return undefined errors.

---

## Parameter Filtering

**User query:**

```sql
| where isempty("{Username}") or AffectedObject contains "{Username}"
````

**Device query:**

```sql
| where isempty("{DeviceName}") or AffectedObject contains "{DeviceName}"
```


## Filtering Microsoft-Initiated Changes

The queries exclude common Microsoft service activity to reduce noise:

* Workplace Analytics
* Microsoft Approval Management
* MS-PIM
* Microsoft Substrate Management
* AAD Lifecycle Management
* Azure AD Identity Governance - User Management
* Microsoft Teams Services

If you want to include system-generated changes, remove this filter block.

```sql
| where InitiatedByApp !in 
("Workplace Analytics", "Microsoft Approval Management","MS-PIM", "Microsoft Substrate Management",
 "AAD Lifecycle Management","Azure AD Identity Governance - User Management","Microsoft Teams Services")
```

## Target Type Behavior

**User query:**

```kql
| where TargetType == "User"
```

**Device query:**

```kql
| where TargetType == "Device"
```

To show both in one view, remove the `TargetType` filter.


## Notes

* Use `.kql` file extension for clarity and compatibility
* Keep parameter names consistent with query filters
* Queries rely on the `AuditLogs` table
* Designed for Azure Monitor Workbooks or Log Analytics
