
# Dell debloat 
This Intune remediation package is designed to detect and remove Dell bloatware from Windows machines in your environment.



# Overview
`Remove.ps1`: This script removes a wide range of Dell applications, services, and AppX packages. It was built by stripping out Dell-specific logic from Andrew S. Taylor's debloat script at # https://github.com/andrew-s-taylor/public/blob/main/De-Bloat/RemoveBloat.ps1

### `Detection.ps1`: Checks for the presence of Dell bloatware by inspecting:
- Installed and provisioned AppX packages

- Win32 apps listed in the registry (via pattern matching)

- Known Dell uninstall executables

If any Dell-related software is detected, the remediation script runs.

### Targeted Applications
Examples of what the script removes:

- Dell SupportAssist & Recovery Plugins

- Dell Command | Update

- Dell Optimizer & Peripheral Manager

- Dell Digital Delivery

- Partner Promo and other Dell AppX entries

###  Notes
-  This script is designed for quiet, unattended execution.
- Includes ASCII banner for a fun visual in logs or if run manually.
- Make sure to validate against any business-critical Dell tools before broad deployment.
