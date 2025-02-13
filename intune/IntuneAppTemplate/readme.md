

# Overview
This template package enhances application installation directly on devices, ideal for scenarios where Intune installations are hindered by slow network conditions. It optimizes both disk space usage and deployment speed by handling installations locally, which can significantly reduce bandwidth consumption.

# Setup
- Copy the IntuneAppTemplate directory and rename it to match your application.
- Place your installer files (e.g., .exe or .msi) in the Files folder within the script directory.
- Modify the install and uninstall scripts to adjust variable names and include the appropriate install flags for your .exe or .msi files.
- Adjust the install and uninstall scripts for things like the variable names to have these value and also install flags on the exe/msi which both differ.
- Execute winutil on install.ps1 to prepare for deployment


- Standard MSI flags

`https://learn.microsoft.com/en-us/windows/win32/msi/standard-installer-command-line-options`
