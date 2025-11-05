# Issue
Our network team identified the root cause of certian client applications connectivity issue on new Dell 16 Pro laptops enrolled in Intune, the Intel Connectivity Performance Suite (ICPS) service and associated drivers conflict with GlobalProtect VPN, preventing the certain clients from establishing a connection due their driver conflicts ignoring certain firewall restrictions/openings. After removing the ICPS fully on a machine they verified that network traffic resumed as expected. 

# Intel Connectivity Performance Suite (ICPS) behavior

The ICPS is an application but also has associated services, drivers, and extensions on the machine.

If you simply uninstalled the application, the services, drivers and extensions would still remain active. 

When Intel Connectivity Performance Suite (ICPS) installs, it adds:
- A Windows service (IntelConnectivityNetworkService) that runs in user mode.
- One or more NDIS filter drivers — typically named icpsExtension and/or icpsComponent.
- The NDIS filter drivers are bound to your physical and virtual network adapters (think of them as sitting in the data path between Windows and your NIC).
- They load automatically during boot as part of the network stack initialization, not when the service starts.

# Service details

- Path exists at `C:\WINDOWS\System32\drivers\Intel\ICPS\IntelConnectivityNetworkService.exe`

- Get service activity
`Get-Service | Where-Object { $_.DisplayName -like "*Intel Connectivity*" }`

- Stop and disable service
```powershell
Stop-Service -Name "IntelConnectivityNetworkService" -Force
Set-Service -Name "IntelConnectivityNetworkService" -StartupType Disabled
```

- Display name `Intel Connectivity Drivers UWD`

# Check for ICPS filter drivers bound to network adapters
Both of these work to see ICPS drivers. 

- `pnputil /enum-drivers | findstr /i icps`
- `pnputil /enum-drivers | Select-String "icps"`


# Windows 10 vs 11 installer
Most modern factory images from Dell, HP, and Lenovo (post–2023) preload the UWP version because Intel began bundling ICPS as part of the Intel Smart Platform Framework, distributed through the Microsoft Store provisioning pipeline.

Older factory images or reimaged systems with 21H2/Win10 = Win32 EXE/MSI version which this uninstaller does not account for.

# Caution
You may have issues reinstalling `IntelConnectivityPerformanceSuite_xx` afterwards because `pnputil /delete-driver /uninstall` leaves the INF class as “retired.”


# Sources:
- https://www.intel.com/content/www/us/en/support/articles/000093451/wireless/wireless-software.html

- https://customercare.primera.com/portal/en/kb/articles/how-do-i-uninstall-and-reinstall-a-printer-driver-pnputil

- https://support.lenovo.com/us/en/solutions/ht513263-how-to-completely-uninstall-intel-connectivity-performance-suite-driver-from-a-system

# Intune deployment
- 64bit powershell
- SYSTEM context

# Demo
```powershell
PS C:\removeICPS> pnputil /enum-drivers | findstr /i icps
Original Name:      icpscomponent.inf
Original Name:      icps_install_driver.inf
Provider Name:      Intel(R) ICPS Install
Class Name:         ICPS
PS C:\removeICPS> ./remove.ps1
Transcript started, output file is C:\Logs\Remove_ICPS_20251105-115754.log
----- Starting Intel Connectivity Performance Suite (ICPS) Full Cleanup -----
Stopping, disabling, and deleting service: IntelConnectivityNetworkService
Service entry 'IntelConnectivityNetworkService' already removed.
Removing service executable and folder at C:\WINDOWS\System32\drivers\Intel\ICPS
Checking for ICPS Appx/MSIX package...
Removing UWP package AppUp.IntelConnectivityPerformanceSuite_40.25.909.0_x64__8j3eq9eme6ctt
Checking for ICPS Win32/MSI package...
No ICPS Win32/MSI package found.
Enumerating ICPS driver packages...
Found ICPS-related driver oem43.inf (Original Published Name:     oem43.inf
icpscomponent.inf
Provider Name:      Intel Corporation
Class Name:         SoftwareComponent
Class GUID:         {5c4c3332-344d-483c-8739-259e934c9cc8}
Driver Version:     09/09/2025 40.25.909.171
Signer Name:        Microsoft Windows Hardware Compatibility Publisher)
Found ICPS-related driver oem17.inf (Original Published Name:     oem17.inf
icps_install_driver.inf
Provider Name:      Intel(R) ICPS Install
Class Name:         ICPS
Class GUID:         {d9b17877-8ca0-4fad-94ca-00b16e47a53f}
Driver Version:     11/30/2022 1.0.0.1
Signer Name:        Microsoft Windows Hardware Compatibility Publisher)
Found ICPS-related driver packages: oem43.inf, oem17.inf
Deleting driver package oem17.inf
Microsoft PnP Utility

Ignoring /force when used with /uninstall to delete driver package.
Driver package uninstalled.
Driver package deleted successfully.
Deleting driver package oem43.inf
Microsoft PnP Utility

Ignoring /force when used with /uninstall to delete driver package.
Driver package uninstalled.
Driver package deleted successfully.
System reboot is needed to complete unconfiguration operations!
Driver cleanup complete - reboot will be required.
Cleaning leftover folder path(s) C:\ProgramData\Microsoft\Windows\AppRepository\Packages\AppUp.IntelConnectivityPerformanceSuite*
Cleaning leftover folder path(s) C:\Users\*\AppData\Local\Packages\AppUp.IntelConnectivityPerformanceSuite*
Verifying ICPS driver removal...
No ICPS drivers remaining in DriverStore.
Service 'IntelConnectivityNetworkService' successfully removed.
Intel Connectivity Performance Suite cleanup complete.
A reboot is highly recommended to finalize removal.
Transcript stopped, output file is C:\Logs\Remove_ICPS_20251105-115754.log
PS C:\removeICPS> pnputil /enum-drivers | findstr /i icps
PS C:\removeICPS>
```
