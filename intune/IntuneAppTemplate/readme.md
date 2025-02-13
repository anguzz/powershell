

# Overview
This template package installs applications directly on devices by dumping the MSI or Exe onto the device locally and calling it through powershell. This serves as a way to bypass slow tenant deployments or network issues for when intune is provisioning a device application on a slow network. From what I've noticed it has a higher install success rate and faster overall install. 

# Setup
- Copy the IntuneAppTemplate directory and rename it to match your application.
- Place your installer files (e.g., .exe or .msi) in the Files folder within the script directory.
- Modify the install and uninstall scripts to adjust variable names and include the appropriate install flags for your .exe or .msi files.
- Adjust the install and uninstall scripts for things like the variable names to have these value and also install flags on the exe/msi which both differ.
- Execute winutil on install.ps1 to prepare for deployment


- Standard MSI flags

`https://learn.microsoft.com/en-us/windows/win32/msi/standard-installer-command-line-options`
