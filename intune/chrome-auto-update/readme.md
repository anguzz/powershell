
# Overview
This PowerShell script, intended for deployment via Intune (or similar tools), configures Google Chrome auto-update settings using registry keys.

While Chrome policies can be managed via ADMX templates, enabling forced auto-updates directly can be challenging. Chrome typically updates upon browser restart, relying on its built-in scheduled task and update service, which often requires the browser to be used. Managing Chrome through the Google Admin Console is another option but adds overhead if extensive configuration isn't needed. This script provides a direct method to influence update behavior via registry settings when running as SYSTEM.

The script modifies the Windows Registry under HKLM:\Software\Policies\Google\Update to ensure Chrome checks for updates regularly and applies them automatically. It creates the necessary keys if they don't exist.

# Registry Keys Configured
- Path: **HKLM:\Software\Policies\Google\Update**

- `AutoUpdateCheckPeriodMinutes` (REG_DWORD): 1440 Sets the update check frequency to every 1440 minutes (24 hours).

- `UpdateDefault` (REG_DWORD): 1:  Sets the default update policy to 1 (Always allow updates).



# Context & Sources
[Registry Settings Source: Keep Google Chrome Auto-Updating with Intune](https://www.cloudpersistence.com/keep-google-chrome-auto-updating-with-intune/)

Discussion on Update Challenges:

[Reddit: Issues configuring auto update for Google Chrome](https://www.reddit.com/r/Intune/comments/16y3s5u/issues_configuring_auto_update_for_google_chrome/)

[Reddit: Understanding Google Chrome updates](https://www.reddit.com/r/sysadmin/comments/tqz8g1/understanding_google_chrome_updates/)

[Reddit: Managing browser updates with Intune (Edge/Chrome)](https://www.reddit.com/r/Intune/comments/1bd1vin/managing_browser_updates_with_intune_edge_chrome/)

# Deployment

- install: `%windir%\sysnative\WindowsPowerShell\v1.0\powershell.exe -Executionpolicy Bypass & '.\install.ps1'`

- uninstall: `%windir%\SysNative\WindowsPowershell\v1.0\PowerShell.exe -NoProfile -ExecutionPolicy ByPass -File .\uninstall.ps1`

- detection: Ensure $expectedCheckMinutes value matches in both install and detection to avoid failure code on deployment 