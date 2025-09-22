## ARM Templates

- **Definition**: JSON files that define Azure resources & configuration using **declarative syntax** (what to deploy, not how).
- **Purpose**: Infrastructure as Code (IaC) → consistent, repeatable deployments.
- **Use Cases**:
  - Redeploy infra quickly (DR, rebuilds).
  - Consistent environments (dev/test/prod).
  - Store in Git for versioning & automation (CI/CD).
  - Enforce compliance & governance.
- **Scope**: Can describe **any Azure Resource Manager resource** (VMs, storage, firewalls, networking, RBAC, etc.).
- **Parameters**: Make templates reusable (e.g., different VM sizes for dev vs prod).
- **Limitations**: Intune configs aren’t ARM-managed → handled via Microsoft Graph.
- **Permissions**: Requires Azure RBAC (Contributor/Owner on resources or groups). Without cloud admin rights, limited to exporting and studying existing templates.
- **Tip**: Start by exporting a resource’s ARM template in the Azure portal → practice modifying/redeploying.

# Azure SKUs

## What is a SKU?
- **SKU** = *Stock Keeping Unit*.
- Represents a unique product/size/option in Azure.
- Determines:
  - Resource type
  - Pricing
  - Features
  - Availability by region

## Examples
- **VM SKUs**: `Standard_D2s_v3`, `Standard_B16als_v2`
- **Storage SKUs**: `Premium_LRS`, `Standard_GRS`
- **Other services**: Load Balancers, App Gateways, etc. all have SKUs.

## SKU Naming Breakdown (VMs)
- **Tier**: `Basic` vs `Standard`
- **Family/Series**:
  - `A` → Entry-level
  - `B` → Burstable
  - `D` → General-purpose
  - `E` → Memory-optimized
  - `F` → Compute-optimized
  - `M` → Massive memory
  - `N` → GPU
- **Size number**: Approx. number of vCPUs (e.g., `D2` = 2 vCPUs)
- **Suffixes**:
  - `a` → AMD CPU
  - `m` → More memory
  - `l` → Low memory
  - `s` → Premium SSD support
  - `v2/v3/v5` → Hardware generation

### Example
`Standard_B16als_v2`
- Standard tier
- Burstable series (B)
- 16 vCPUs
- AMD, low memory, Premium SSD support
- 2nd generation hardware

## Key Notes for AZ-104
- **Region-specific**: Not all SKUs are available in every region.
- **Command**: List VM SKUs by region
  ```bash
  az vm list-skus --location westus --output table


