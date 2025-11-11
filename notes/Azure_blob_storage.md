# Azure Blob Storage Notes

## What’s a Blob

* **Blob** = Binary Large Object → unstructured data (images, logs, video, binaries, etc.)
* Part of an **Azure Storage Account**
* A storage account can have unlimited **containers**, and containers can have unlimited **blobs**


## Blob Types

Azure supports multiple blob types depending on the workload:

* **Block Blobs** → best for text and binary data; optimized for uploads and storage.
* **Append Blobs** → optimized for append-only workloads (e.g., logs).
* **Page Blobs** → optimized for random read/write operations, used by Azure virtual machine disks (VHDs).

```
Storage Account (like a drive)
│
├── Container (like a folder)
│   ├── Blob (file: installer.msi → BlockBlob)
│   ├── Blob (file: logs.txt → AppendBlob)
│   └── Blob (file: disk.vhd → PageBlob)
```

## Azure Storage Explorer & Portal

* **Azure Storage Explorer** desktop client → manage blobs directly
* Portal link: [Azure Storage Explorer (portal)](https://portal.azure.com/?icid=azure-storage-explorer#home)
* Azure storage explorer download: [Azure Storage Explorer download]( https://azure.microsoft.com/en-us/products/storage/storage-explorer/#Download-4) 
* Blob shows up under **Object Storage**
* If you’re a full admin you can configure:

  * Properties, networking, security, file services
  * Enable static website hosting
  * Add **CDN profiles** and **custom domains**
  * Enable **Azure Defender** (threat protection, malware scanning \~\$0.15/scanning per GB)
  * Create **private endpoints**
  * Configure **data protection** (soft delete, retention, snapshots)


A bunch of stuff in the portal I noticed poking around.

## Identity & Access

* Integrated with **Entra ID / AD**
* RBAC roles available:

  * **Storage Blob Data Owner** → Full control over blob containers and data. Can read, write, delete, set access policies, and assign RBAC roles.
  * **Storage Blob Data Contributor** → Can read, write, and delete blob data. Cannot manage RBAC role assignments or access policies.
  * **Storage Blob Data Reader** → Read-only access to blob data (can list containers, read blobs and metadata, but not write or delete).
  * **Storage Blob Data Delegator** → Allows a security principal to generate **user delegation SAS tokens** (used to securely grant temporary access to blobs).
* **Anonymous/public access** possible → disabled by default and not recommended (risk of breaches)




## Storage Explorer Application (Windows)

* **Azurite**: In the application you can create an Azure Storage emulator (now known as **Azurite**) to create containers, blobs, queues, and tables locally, and test apps/scripts without touching production.
* **Resource types**: You can manage a whole **storage account** or an **individual blob container**, as well as queues, individual file shares, tables, etc.
* **Best practice for connecting**:

  * Use **Subscription (Azure AD login)** whenever possible.
  * This avoids handling **account keys** or **SAS tokens**, and instead uses your Azure AD identity with RBAC roles (e.g., Blob Contributor).
  * Benefits: No secrets to manage, least-privilege access, role-based updates apply automatically, and all actions are logged under your user for auditing.
* **When to use keys/SAS**:

  * For service accounts, pipelines, or when you need to grant temporary access outside your tenant.
  * Keys = full account access (avoid sharing).
  * SAS = scoped access (container/file-level, limited time).



------
Some interesting features on the portal.

## Encryption

* **Server-side encryption** is **always on** (cannot be disabled)
* Encryption key options:

  * **Microsoft-managed keys** (default, rotated by MS)
  * **Customer-managed keys (CMK)** → stored in Azure Key Vault, you manage rotation
  * **Customer-provided keys (CPK)** → supplied by client per request, you manage externally





## Front Door & CDN

* **Azure Front Door Standard** → delivery optimized (caching static content)
* **Azure Front Door Premium** → adds security optimizations (WAF, private link)

## Data Management

* **Redundancy** across regions: LRS, ZRS, GRS, RA-GRS
* **Inventory rules** for reporting on usage
* **Lifecycle management** for automatic tiering, archiving, or deleting blobs


## Monitoring & Insights

* **Azure Monitor**: metrics, custom dashboards, failure tracking, logs
* **Azure Service Health** monitors blob uptime and incidents
* **Security** → via Microsoft Defender for Cloud (sensitive data protection, malware scanning)


## Automation

* **Automation tasks**
  * Example: monthly cost email, auto-delete old blobs, move/archive files
  * Default templates available in the portal
  * Logic Apps–based under the hood
  
* **Partner Solutions tab** for:

  * Backup/Recovery → Rubrik, Veeam, Cohesity, Commvault
  * Data Analytics → Databricks, Demio, Confluent, Snowflake
  * Migration/Management → Atempto, Cirata, Data dynamics, Kompromise
  * Network Storage → NetApp, Nasuni, Qumulo, Weka


## Shared Access Signatures (SAS)

* Allows fine-grained delegated access to blobs.
* Can be **account SAS**, **service SAS**, or **user delegation SAS** (with Entra ID).
* Good for giving apps or temporary users limited access without full RBAC.


## Networking & Security Options

* **Private endpoints** → restrict blob access to a VNet.
* **Firewalls and VNet rules** → block public traffic except allowed IPs/ranges.
* **Immutable storage (WORM)** → write once, read many, for compliance.
* **Defender for Storage** → anomaly detection, sensitive data classification, and malware scanning on upload.


## Cost Optimization

* **Lifecycle rules** (move data from Hot → Cool → Archive automatically).
* **Azure Cost Analysis** → monitor blob storage spend by access tier and transactions.
* **Reserved capacity** discounts available if you commit upfront.

## Access Tiers

For cost and performance optimization:

* **Hot** → optimized for frequent access, highest storage cost, lowest access cost.
* **Cool** → lower storage cost, higher access cost, minimum 30-day retention.
* **Archive** → cheapest storage, data must be rehydrated before access, minimum 180-day retention.
