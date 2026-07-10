

# Debug-GroupLicenseAssignment.ps1 

`Debug-GroupLicenseAssignment.ps1` walks Microsoft Graph to investigate a user's license state end-to-end:

- Pulls license assignment states and flags any in `ActiveWithError`
- Inspects each `assignedByGroup` reference (group type, sync source, license processing state) and checks whether the user is still a direct or transitive member
- Optionally pulls Lifecycle Workflow task processing results for the user
- Optionally forces `reprocessLicenseAssignment` to surface the underlying reconciliation error

Read-only by default. Only mutates state when `-Reprocess` is passed.

## Background

A terminated user's license removal task failed as part of the standard **Entra Lifecycle Workflow** (built-in "Remove all licenses for user" task). The workflow GUI only surfaced a generic error, so I dug into it via **Microsoft Graph** to identify the actual root cause.

This writeup walks through the investigation in case another engineer runs into the same pattern. The custom on-prem group removal step is intentionally out of scope here (that failure had a separate, known cause).

---

## TL;DR

- The built-in **"Remove all licenses for user"** task in Lifecycle Workflows returns a **generic** `failureReason` in both the portal and Graph:
  > `"User license is inherited from a group membership and it cannot be removed directly from the user."`
- The **actual** root cause was a **service plan dependency conflict** between a group-assigned SKU (M365 E5) and two directly assigned SKUs (Visio Plan 2 + Project Plan 3).
- Standard reconciliation and `reprocessLicenseAssignment` both fail with the real error once you call them directly.
- Removing the conflicting **direct** licenses first, then reprocessing, clears the stuck group-assigned license cleanly.

---

## Step 1 - Pull the Lifecycle Workflow task result via Graph

The portal only shows the summary. The task-level `failureReason` requires two Graph calls.

### Get the userProcessingResult ID for the subject

```http
GET https://graph.microsoft.com/beta/identityGovernance/lifecycleWorkflows/workflows/{workflowId}/userProcessingResults?$filter=subject/id eq '{userObjectId}'
````

Grab the `id` from the response - that's the `userProcessingResultId`.

### Get taskProcessingResults filtered to failures

```http
GET https://graph.microsoft.com/beta/identityGovernance/lifecycleWorkflows/workflows/{workflowId}/userProcessingResults/{userProcessingResultId}/taskProcessingResults?$filter=processingStatus eq 'failed'
```

**Response (redacted):**

```json
{
  "value": [
    {
      "processingStatus": "failed",
      "failureReason": "User license is inherited from a group membership and it cannot be removed directly from the user.",
      "task": {
        "displayName": "Remove all licenses for user",
        "category": "leaver",
        "taskDefinitionId": "8fa97d28-3e52-4985-b3a9-a1126f9b8b4e"
      }
    }
  ]
}
```

`taskDefinitionId: 8fa97d28-3e52-4985-b3a9-a1126f9b8b4e` is the well-known ID for the built-in "Remove all licenses for user" task.

That message is intentionally generic. It's the same string regardless of which SKU or plan actually blocked removal.

***

## Step 2 - Identify the group and rule state

Pull the group referenced by `assignedByGroup` on the user's license state:

```http
GET https://graph.microsoft.com/v1.0/groups/{groupId}?$select=id,displayName,groupTypes,securityEnabled,mailEnabled,onPremisesSyncEnabled,membershipRule,membershipRuleProcessingState
```

Confirmed:

* Cloud-only dynamic security group
* `membershipRuleProcessingState: On`
* Rule uses attribute-based termination signals (rule details omitted)

***

## Step 3 - Confirm attributes are synced correctly

On-prem AD had the correct termination attribute set. Comparing to Entra:

```http
GET https://graph.microsoft.com/v1.0/users/{userObjectId}?$select=onPremisesExtensionAttributes,employeeId,onPremisesLastSyncDateTime
```

* `onPremisesExtensionAttributes.extensionAttribute2` reflected the terminated state
* `onPremisesLastSyncDateTime` was current
* User was already removed from the dynamic group (verified via `/members` filter)

Group membership was correct - the license just hadn't cleaned up.

***

## Step 4 - Check group license processing state

```http
GET https://graph.microsoft.com/v1.0/groups/{groupId}?$select=id,displayName,assignedLicenses,licenseProcessingState
```

**Response (trimmed):**

```json
{
  "assignedLicenses": [
    {
      "disabledPlans": [ "...<x> service plan GUIDs..." ],
      "skuId": "06ebc4ee-1bb5-47dd-8120-11324bc54e06"
    }
  ],
  "licenseProcessingState": { "state": "ProcessingComplete" }
}
```

Group SKU: `06ebc4ee-1bb5-47dd-8120-11324bc54e06` = **SPE\_E5 (Microsoft 365 E5)**  
Group processing = complete. User no longer a member. But the license was still attached to the user with `assignedByGroup` pointing to this group, and stuck in `ActiveWithError` / `DependencyViolation` state.

At this point it looked like a stuck reference, so the standard fix is to force a user-side license reprocess.

***

## Step 5 - Force reprocess (this is where the real error surfaced)

**Requires `User.ReadWrite.All` or `Directory.ReadWrite.All` Graph scope + a role like User Administrator, License Administrator, or Global Administrator on the signed-in principal.**

```http
POST https://graph.microsoft.com/v1.0/users/{userObjectId}/reprocessLicenseAssignment
```

**Response:**

```json
{
  "error": {
    "code": "Request_BadRequest",
    "message": "License assignment failed because service plan fe71d6c3-a2ea-4499-9778-da042bf08063 depends on the service plan(s) 5dbe027f-2339-4123-9542-606e4d348a72"
  }
}
```

That's the real error. `reprocessLicenseAssignment` surfaces the full reconciliation failure directly. The Lifecycle Workflow task catches it upstream and reports the generic "inherited from group" message instead.

***

## Step 6 - Decode the service plans

Using the Microsoft service plan reference:

| Service Plan ID                        | Plan Name                              | Role                          |
| -------------------------------------- | -------------------------------------- | ----------------------------- |
| `fe71d6c3-a2ea-4499-9778-da042bf08063` | Higher-tier SharePoint plan            | Enabled somewhere             |
| `5dbe027f-2339-4123-9542-606e4d348a72` | SHAREPOINTSTANDARD (SharePoint Plan 1) | Required parent, but disabled |

The dependency: the higher SharePoint plan requires the base SharePoint plan to also be enabled. Removing one without the other triggers `DependencyViolation`.

***

## Step 7 - Reconstruct the conflict

The user held three SKUs, each touching SharePoint service plans:

| SKU ID                                 | SKU Name       | Assignment | Relevant State                           |
| -------------------------------------- | -------------- | ---------- | ---------------------------------------- |
| `06ebc4ee-1bb5-47dd-8120-11324bc54e06` | M365 E5        | Group      | SharePoint child plan enabled            |
| `c5928f49-12ba-48f7-ada3-0d743a3601d5` | Visio Plan 2   | Direct     | SharePoint child plan enabled            |
| `53818b1b-4a27-454b-8896-0dba576410e6` | Project Plan 3 | Direct     | `5dbe027f...` (SharePoint base) DISABLED |

**The conflict:** the E5/Visio SKUs enable a higher SharePoint plan that depends on `5dbe027f...`, while Project Plan 3 has `5dbe027f...` disabled. Any attempt to reconcile trips over the dependency.

***

## Why the Lifecycle Workflow task can't recover

The built-in "Remove all licenses for user" task removes all licenses in a single reconciliation. When Entra's intermediate state trips the dependency violation, the entire operation rolls back. The task then reports the generic "inherited from group" message, which is misleading - the actual problem is the plan dependency, not the group inheritance.

***

## Resolution

Option A - clean up directly assigned SKUs first, then reprocess:

```http
POST https://graph.microsoft.com/v1.0/users/{userObjectId}/assignLicense
Content-Type: application/json

{
  "addLicenses": [],
  "removeLicenses": [
    "c5928f49-12ba-48f7-ada3-0d743a3601d5",
    "53818b1b-4a27-454b-8896-0dba576410e6"
  ]
}
```

Then:

```http
POST https://graph.microsoft.com/v1.0/users/{userObjectId}/reprocessLicenseAssignment
```

Option B - if you already have User Administrator / License Administrator active, just clear all licenses on the user directly and skip the workflow retry.


Verification: I attempted this and it confirms with the conflicting direct SKUs removed, the intermediate state no longer trips the dependency violation, and normal reconciliation drops the group-assigned license as expected.'

***

## Broader takeaway

* The Lifecycle Workflow's built-in license removal task **swallows the real error**. Always cross-check with `reprocessLicenseAssignment` or `assignLicense` directly to get the actual reason.
* **`DependencyViolation`** on group-assigned licenses is worth flagging - it often signals a misaligned `disabledPlans` configuration between overlapping SKUs (base SKU + add-ons like Visio/Project). Any terminated user with the same SKU combination will hit the same failure until the config is fixed.
* Fixing the root cause means aligning the disabled plans configuration across all SKUs a user might hold, so no plan enabled elsewhere depends on a plan disabled somewhere else.

***

## References

* [List taskProcessingResults for a user](https://learn.microsoft.com/en-us/graph/api/identitygovernance-userprocessingresult-list-taskprocessingresults?view=graph-rest-1.0)
* [user: reprocessLicenseAssignment](https://learn.microsoft.com/en-us/graph/api/user-reprocesslicenseassignment?view=graph-rest-1.0\&tabs=http)
* [Force user license processing to resolve errors](https://docs.azure.cn/en-us/entra/fundamentals/licensing-groups-resolve-problems#force-user-license-processing-to-resolve-errors)
* [How to identify and resolve licensing problems for a group](https://docs.azure.cn/en-us/entra/fundamentals/licensing-groups-resolve-problems)
* [Product names and service plan identifiers for licensing](https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference)
* [Lifecycle Workflow built-in tasks](https://learn.microsoft.com/en-us/entra/id-governance/lifecycle-workflow-tasks)




