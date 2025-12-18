# .NET Removal Package (Tanium)

This document outlines the standardized approach for discovering and removing **.NET Core / .NET SDKs / runtimes** from endpoints using the **Microsoft .NET Uninstall Tool** deployed and executed via **Tanium**. This is useful for vulnerabilities related to EOL/obsolete dotnet core or runtime versions.


The process is intentionally split into **two phases**:

1. Deploying the .NET Uninstall Tool as **Software** in Tanium
2. Executing removal actions via a **Tanium Package**

This separation allows controlled rollout, reuse, auditing, and safer execution.


## Overview

* **Tool Used:** Microsoft .NET Uninstall Tool (`dotnet-core-uninstall`)
* **Deployment Method:** Tanium Software + Tanium Package
* **Use Cases:**

  * Removing end-of-life .NET runtimes (e.g., .NET 5 / 6 / 7)
  * Cleaning up unused SDKs on servers or workstations
  * Supporting vulnerability remediation and compliance efforts


## Phase 1: Deploy .NET Uninstall Tool (Software)

### Download Tool

* Source (official Microsoft repo):
  [https://github.com/dotnet/cli-lab/releases](https://github.com/dotnet/cli-lab/releases)

* Download the **latest Windows release** of the .NET Uninstall Tool

* Prefer the **MSI installer** so Tanium automatically populates:

  * Install command
  * Uninstall command
  * Version detection

### Tanium Software Configuration

* Package the MSI as **Software** in Tanium
* Deploy to target endpoints prior to any removal actions
* Ensure installation completes successfully before proceeding to Phase 2

> Using Software ensures the binary is locally available and versioned before execution.


## Phase 2: Execute Removal via Tanium Package

Once the tool is installed, it can be invoked through a Tanium **Package**.

### Example Commands

List all installed .NET components on an endpoint:

```cmd
cmd.exe /d /c dotnet-core-uninstall.exe list
```

Additional commands (examples):

* Remove specific runtime versions
* Remove SDKs only
* Remove all versions below a defined threshold

(Refer to Microsoft documentation for exact CLI flags.)

### Package Configuration

* **Verification Query:** None required
* **Execution Context:** System
* **Output:** Captured in Tanium action results


## Validation & Auditing

After package execution:

1. Navigate to:

   * **Interact** → **Single Endpoint View** → **Details**
   * **Direct Connect** → **Reporting** → **Actions**
2. Locate the corresponding **Action ID**
3. Review:

   * Exit codes
   * Standard output
   * Standard error (if applicable)

This provides a clear audit trail of execution and success/failure status.


## Notes & Best Practices

* Always **list installed versions** before removing
* Avoid removing:

  * In-use runtimes required by production applications
  * Bundled runtimes installed with vendor software unless verified safe
* Test removal commands on a small pilot group before broad deployment
* Coordinate with application owners when removing shared runtimes


## References

* Microsoft Overview:
  [https://learn.microsoft.com/en-us/dotnet/core/additional-tools/uninstall-tool-overview?pivots=os-windows](https://learn.microsoft.com/en-us/dotnet/core/additional-tools/uninstall-tool-overview?pivots=os-windows)

* CLI Usage & Removal Options:
  [https://learn.microsoft.com/en-us/dotnet/core/additional-tools/uninstall-tool-cli-remove?pivots=os-windows](https://learn.microsoft.com/en-us/dotnet/core/additional-tools/uninstall-tool-cli-remove?pivots=os-windows)
