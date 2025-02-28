# Overview
This package is designed to configure notification settings specifically for the `https://github.com/Romanitho/Winget-AutoUpdate` app by targeting the registry key `HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.WAU.Notification`. The main goal is to reduce the intrusiveness of Winget app auto update notifications while maintaining their visibility in the notification panel.

# Features
- Disables Popup Banners: Prevents update notifications from appearing as pop-ups, reducing disruption during active use.
- Suppresses Lock Screen Notifications: Ensures that update notifications do not appear on the lock screen, maintaining privacy.
- Silences Notification Sounds: Turns off sounds for Winget auto update notifications, avoiding auditory interruption.

These settings are specifically tailored to not remove the notifications entirely; instead, they will still be accessible from the notification panel, allowing users/admins to review them updated applications statuses. 

# Manual Configuration
These values can be adjusted client side under `System > Notifications > Application Updates` if WinGet-AutoUpdate is installed on the device. 

# Deployment
This script is ideal for deployment via Microsoft Intune or similar management tools to ensure a consistent configuration across multiple devices using Winget. Ensure you deploy in a user context silently if deploying via intune as running as system will place in the system's user account. 


# Complete Notification Disabling
If you prefer to disable all notifications for Winget auto updates, include the following line in your install.ps1 script, the others can be removed
`New-ItemProperty -Path $registryPath -Name "Enabled" -Value 0 -PropertyType DWORD -Force`