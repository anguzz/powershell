# Tanium Connect – Alerting, Email, Dashboards, and Azure Blob Storage

These are my notes for  **how Tanium Connect is used for alerting, reporting, dashboards, and external storage**. It focuses on **what each component does**, **prerequisites**, and **correct setup order**.

## 1. Tanium Alerting (High Level)

Tanium alerting is implemented through **Connect connections**.

Common use cases:

* Alert when a **service is stopped**
* Send **scheduled reports** (CSV / HTML)
* Distribute **dashboard outputs**

Alerting is built from:

1. A **Source** (Saved Question or Report)
2. A **Destination** (Email or Cloud Storage)
3. A **Schedule** (optional but typical for alerts)

## 2. Email Alerts – Prerequisites

Email alerting requires an **Email Server Profile**.

### Required

* Microsoft Entra ID application
* Authentication via **Client Secret**
* Delegated permissions for Microsoft Graph (Mail.Send)

### Where to configure

```
Connect > Overview > Settings (gear icon) > Email Server
```

### Email Server Profile – Key Fields

* Provider: Microsoft Office 365 Graph
* Host: graph.microsoft.com
* Authority Host: login.microsoftonline.com
* Port: 443
* Tenant ID
* Client ID
* Client Secret
* From User (service mailbox)

Once created, the profile becomes selectable in **Email destinations**.

## 3. Creating an Email-Based Alert Connection

**Best for:**

* Service-down alerts
* Operational notifications
* Weekly summaries

### Steps

```
Connect > Connections > Create Connection
```

1. **Source**

   * Saved Question (example: stopped service query)
   * Scope via Computer Group

2. **Destination**

   * Email (O365 & SMTP)
   * Select Email Server Profile
   * Configure recipients and subject

3. **Schedule**

   * Enable schedule
   * Example: every 10–20 minutes for service alerts

4. Save and enable

## 4. Dashboards – Key Concepts

Dashboards **do not query sensors directly**.

**Rule:**

> A dashboard must be backed by a **Report**.

Limitations:

* Reports determine which sensors and fields are available
* If the data is not in Reporting, it cannot appear in a dashboard

## 5. Report and Dashboard Creation Flow

### Step 1 (Optional): Add Sensor to Reporting

Only required if the sensor is **not already available** in Reporting.

```
Interact > Overview > Settings (gear icon) > Actions > Add Sensor to Reporting
```

### Step 2: Create a Report

Reports act as the **data source** for dashboards.

```
Reporting > Reports > Create Report
```

Why reports matter:

* Dashboards read from reports
* Connect can export reports (CSV / HTML)
* Reports define filtering and grouping

### Step 3: Create a Dashboard

```
Reporting > Dashboards > Create Dashboard
```

* Select an existing report
* Configure visuals and layout
* Dashboards can later be exported via Connect

## 6. Azure Blob Storage – Use Case

**Best for:**

* Hosting HTML dashboards
* Centralized exports
* Long-term storage

## 7. Azure Blob Storage – Prerequisites

### Required Infrastructure

1. Azure Storage Account
2. Blob Container
3. Storage Account Key

### Required Tanium Configuration

* Network egress allow rule
* Must be configured on the **Primary Tanium Server** (not via UI only)

## 8. Network Egress Requirement (Critical)

Without this, uploads fail with **HTTP 500**, even with valid credentials.

### Required Egress Rule

```
Destination: <storage-account-name>.blob.core.windows.net
Port: 443
```

This allows Tanium Connect to reach Azure Blob endpoints.

## 9. Creating an Azure Blob Storage Profile

```
Connect > Overview > Settings (gear icon) > Cloud Storage > Create
```

### Required Fields

* Provider: Microsoft Azure Blob Storage
* Container Name
* Account Name
* Storage Account Key
* Path Prefix (optional)
* Content Set: Connect

Once created, this profile becomes selectable in **Cloud Storage destinations**.

## 10. Creating a Blob-Based Connection (HTML Dashboard)

**Best for:**

* Publishing dashboards as HTML
* Sharing via internal web access

### Example Configuration

* Source: Report or Dashboard export
* Destination: Azure Blob Storage
* Container Name: tanium-html
* Path Prefix: (optional)

## 11. Recommended Setup Order (End-to-End)

1. Configure **network egress** on Tanium server
2. Create Azure **storage account and container**
3. Create **Email Server Profile** (if alerting)
4. Create **Cloud Storage Profile** (if exporting)
5. Ensure required **sensors exist in Reporting**
6. Create **Report**
7. Create **Dashboard** (optional)
8. Create **Connect connection**
9. Enable schedule

## Summary

* Alerts = Connect + Saved Question + Email
* Dashboards = Reporting + Reports
* HTML dashboards = Reports + Connect + Azure Blob
* Egress rules are mandatory for cloud storage
* Reports are the foundation for dashboards and exp
