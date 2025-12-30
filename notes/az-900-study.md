# Azure Fundamentals – Training Notes

> These notes are based primarily on Azure training material, with light rewording for clarity and structure.

---

## Cloud Deployment Models

### Private Cloud

A **private cloud** is a cloud environment used by a single organization. It is often the natural evolution of a traditional on-premises datacenter, offering cloud characteristics (self-service, scalability, automation) while remaining dedicated to one entity.

---

### Public Cloud

A **public cloud** is built, owned, and operated by a third-party provider and delivered over the internet.

Examples:

* Microsoft Azure
* Amazon Web Services (AWS)
* Google Cloud Platform (GCP)

---

### Hybrid Cloud

A **hybrid cloud** combines private and public cloud environments, allowing data and applications to move between them. This model is common for organizations transitioning to the cloud or with regulatory constraints.

---

### Multi-Cloud

A **multi-cloud** strategy uses multiple public cloud providers at the same time (for example, Azure + AWS). This can reduce vendor lock-in and increase resilience, but adds operational complexity.

---

### Azure VMware Solution

**Azure VMware Solution (AVS)** allows organizations to run existing VMware workloads natively in Azure, providing cloud scalability while retaining VMware tooling and familiarity.

---

## Cloud Cost Model

### Consumption-Based Pricing

Cloud computing uses a **pay-as-you-go** model.

* **CapEx (Capital Expenditure):** One-time, upfront costs for physical infrastructure.
* **OpEx (Operational Expenditure):** Ongoing costs for services consumed over time.

Cloud computing falls under **OpEx**, since you pay only for what you use.

---

### Shared Responsibility Model

Security and management responsibilities are shared between the cloud provider and the customer. The provider secures the **cloud infrastructure**, while the customer secures what they deploy **in the cloud** (OS, configurations, identities, data, etc.).

---

## Azure Cost Management

### Cost Influencing Factors

Azure resource costs depend on:

* **Resource type:** VMs, Blob Storage, databases, networking, etc.
* **Resource configuration:** Size, performance tier, redundancy.
* **Region/geography:** Pricing varies by Azure region.
* **Network traffic:** Inbound traffic is typically free; outbound bandwidth is billed.
* **Subscription type:** Some subscriptions include usage allowances.
* **Azure Marketplace:** Third-party solutions (firewalls, appliances, software) may add additional costs.

---

### Pricing Calculator

The **Azure Pricing Calculator** estimates costs for compute, storage, and networking based on selected configurations.

URL:
[https://azure.microsoft.com/pricing/calculator/](https://azure.microsoft.com/pricing/calculator/)

Best practices:

* Define requirements clearly.
* Compare storage tiers, redundancy options, and regions.

---

### Cost Management + Billing

Azure Cost Management allows you to:

* Track and analyze spending
* Create budgets
* Set alerts for cost thresholds

---

### Resource Tagging

Tags are **key-value pairs** applied to Azure resources to provide metadata.

Common use cases:

* Cost tracking
* Resource organization
* Governance and compliance
* Operations and automation

Tags can be managed via:

* Azure Portal
* PowerShell
* Azure CLI
* ARM templates
* REST API

---

## Governance and Compliance Tools

### Microsoft Purview

A unified solution for **data governance, risk, and compliance**, providing visibility into data across environments.

---

### Azure Policy

Azure Policy allows you to **create, assign, and enforce rules** that govern Azure resources, ensuring compliance with organizational standards.

---

### Resource Locks

Resource locks prevent **accidental deletion or modification** of resources.

Lock types:

* Delete
* Read-only

Managed via:

* Azure Portal
* PowerShell
* Azure CLI
* ARM templates

---

### Service Trust Portal

[https://servicetrust.microsoft.com/](https://servicetrust.microsoft.com/)

Provides compliance documentation, audits, and certifications for Microsoft cloud services.

Key sections:

* Home
* My Library (pinned documents + update notifications)
* All Documents

---

## Tools for Interacting with Azure

### Management Tools

* **Azure Portal:** Web-based management console
* **Azure Cloud Shell:** Browser-based shell (PowerShell or Bash)
* **Azure PowerShell:** PowerShell cmdlets for Azure management
* **Azure CLI:** Cross-platform CLI using Bash-style commands

---

### Azure Arc

Azure Arc extends Azure management, governance, and monitoring to **hybrid and multi-cloud environments** using Azure Resource Manager.

Supported resources outside Azure:

* Servers
* Kubernetes clusters
* Azure data services
* SQL Server
* Virtual machines (preview)

---

## Infrastructure as Code

### Azure Resource Manager (ARM)

ARM is Azure’s deployment and management service. Every resource operation in Azure goes through ARM.

**ARM Templates**

* JSON-based
* Declarative (define *what* you want, not *how*)
* Repeatable deployments
* Supports orchestration and modular design

---

### Azure Bicep

Bicep is a **simplified declarative language** that compiles to ARM templates.

Benefits:

* Cleaner syntax than JSON
* Full support for Azure resource types
* Modular and reusable
* Repeatable and predictable deployments

---

## Monitoring and Health

### Azure Advisor

Azure Advisor analyzes your environment and provides recommendations in five categories:

* Reliability
* Security
* Performance
* Operational Excellence
* Cost

Available via Azure Portal and APIs, with optional notifications.

---

### Azure Service Health

Provides visibility into Azure service issues at different levels:

1. **Azure Status:** Global service health
2. **Service Health:** Services and regions you use
3. **Resource Health:** Health of individual resources (e.g., a VM)

Alerts can be configured using Azure Monitor.

---

### Azure Monitor

Azure Monitor is the core monitoring platform for Azure.

Key components:

* **Log Analytics:** Query logs and telemetry
* **Azure Monitor Alerts:** Trigger notifications based on thresholds
* **Application Insights:** Monitor application performance and availability

