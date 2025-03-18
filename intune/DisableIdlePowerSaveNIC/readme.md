
# Overview
Disables Power idle save for Network connections

This package is built on top
https://github.com/HarmVeenstra/Powershellisfun/tree/main/Disable%20Idle%20Power%20Save


More info:
https://powershellisfun.com/2024/03/21/disabling-idle-power-save-using-intune-and-powershell/

# Updates
- Console output on to see which adapters have Enabled/Disabled Network power saving. 
- Generate log file at `C:\Logs\IdlePowerSavingLog.txt` to log current status on network cards and changes against them

# Reauthenticatation
- Please note making changes against Network connections advanced properties will cause the client to reauthenticate causing a short disconnect during this period.
