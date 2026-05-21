# Azure Automation + Hybrid Worker

Azure logic apps, automation accounts and azure arc let you do some pretty powerful stuff. You can setup logic apps with workbooks that can be tied to an on prem handler to basically take on prem actions whenever a logic apps criteria are met. This can be additionally tied to entra lifecyle workflows for automation there if needed. 

## Basic flow

```
Azure Automation Account
    ↓
Runbook (PowerShell / Python)
    ↓
Execution context:
    - Azure (cloud sandbox)
    - OR Hybrid Runbook Worker (on-prem / Arc server)
    ↓
Runs commands and returns output/logs
```

## What this means

* Azure Automation is the **control plane**
* Runbooks are just **scripts stored and managed in Azure**
* By default:
  * Scripts run in Azure (limited access)
* If you use a Hybrid Worker:
  * Scripts run **on a real server (VM or on‑prem)**
  * Can access:
    * Active Directory
    * internal systems
    * private network resources

Microsoft describes this as:

* Runbooks are stored in Azure and **executed locally on machines to manage resources in that environment**

# Lifecycle Workflows + Automation (Hybrid Pattern)

With an azure automation setup you can tie it to an entraID lifecycle workflow as an extension. 

## End-to-end flow

```
Lifecycle Workflow (Joiner / Mover / Leaver)
        ↓
Custom Task Extension
        ↓
Azure Logic App
        ↓
(HTTP / webhook / connector)
        ↓
Azure Automation Runbook
        ↓
Hybrid Runbook Worker (Arc-enabled server)
        ↓
Execute PowerShell locally (AD / on-prem / infra)
```

***

## What each piece does

### Lifecycle Workflows

* Triggers based on:
  * user creation
  * attribute changes
  * joiner / mover / leaver events
* Has built-in tasks, but limited

***

### Custom Task Extension

* Extends workflows beyond built-in actions

### Azure Logic App

* Acts as the **orchestration layer**
* Receives workflow trigger
* Can:
  * pull user attributes
  * call Graph APIs
  * branch logic
  * trigger downstream automation



### Integration to Runbooks

* Logic App triggers Automation via:
  * webhook
  * HTTP call


***

### Runbook + Hybrid Worker

* Runbook executes on:
  * Hybrid Worker (on-prem / Arc server)
* Script runs **locally in that environment**

Used to:

* modify AD users
* update attributes
* run infra automation
* interact with internal systems

***

# How this is used (high level)

This pattern is useful when:

* Lifecycle workflows need to do something **not supported natively**
* Actions must happen:
  * on-prem
  * in AD
  * in private network systems

Examples:

* Update AD attributes based on Entra changes
* Add/remove users from on-prem groups
* Enable/disable accounts
* Trigger custom provisioning logic

***

# Mental model (simple)

```text
Lifecycle Workflow = trigger (identity event)

Logic App = orchestrator

Runbook = script

Hybrid Worker = where the script actually runs
```

***

# Key takeaway

* Azure handles **orchestration and triggering**
* Hybrid Worker handles **execution in your environment**
* Logic Apps connect everything together

This allows you to:

> Trigger automation from the cloud and execute it locally across hybrid environments
