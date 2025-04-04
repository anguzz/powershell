# AutoPilot Enrollment (APE) and Hash Generator

This PowerShell script provides a simple interface for enrolling devices into Windows Autopilot and generating Autopilot hardware hashes. It is designed to automate the generation and transfer of the hardware hash file, simplifying the device enrollment process for system administrators.

## Overview

Currently, when a new device during the out-of-box experience (OOBE) needs to be enrolled in Autopilot, a desktop support technician manually intervenes by using a shell (accessible via Shift+Fn+F10) to execute PowerShell commands or run a script. The script, generates a CSV hash file which then must be manually copied onto a USB drive by the technician. This hash file then has to be uploaded to intune 

To simplify this process, we aim to automate the generation of the CSV file and its transfer to and from the USB drive. The script enhances the operational efficiency by reducing manual intervention and minimizing the risk of human error.

Alteneratively, if run by an Administrator with the correct Entra RBAC, the device can be rolled during this script. 


## Features

- **Enroll Device in Autopilot:** Facilitates the online enrollment of a device into Windows Autopilot.
- **Generate Autopilot Hardware Hash:** Generates a hardware hash of the device and provides an option to store it on a USB drive.

## Usage

1. **Start the OOBE Process**: Begin setting up your new device with Windows installed.
2. **Open PowerShell during OOBE**:
   - During the initial setup screens, press `Shift+F10` to open the command prompt.
   - At the command prompt, type `powershell` and press Enter to switch to PowerShell.
3. **Navigate to the Script**:
   - If your script is located on a USB drive, you might first need to change to the drive by entering the drive letter followed by a colon (e.g., `E:`) and pressing Enter.
   - Use `cd` to change to the directory containing your script. For example, if your script is in the root directory of the USB drive, simply ensure you're in the correct drive as mentioned.
4. **Run the Script**:
   - Execute the script by typing the following command and pressing Enter:
     ```powershell
     .\enroll_autopilot.ps1
     ```
   - You may have to run the `set.bat` file to get an elevated shell 
   - Follow any on-screen prompts provided by the script to complete the hash generation or other tasks.


# Autopilot enrollment script

Microsoft's site states you can ennroll a device to autopilot via the following script found at `https://learn.microsoft.com/en-us/autopilot/add-devices`

```
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
PowerShell.exe -ExecutionPolicy Bypass
Install-Script -name Get-WindowsAutopilotInfo -Force
Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned
Get-WindowsAutopilotInfo -Online
```


It states at minimum an Intune Administator role is required to enroll the device. I tested with an account that has an Intune Admin RBAC and it did not go through, instead it would prompt for admin consent. I found more users who also encountered the same. Other users claimed they just used a global admin account to enroll the device using this script. Although this may be an issue relateed to the consent flow for microsoft entra apps. 

 I then did more research and found that the AzureAD module used in the `get-windowsautopilotinfo.script` has been deprecated, and you have to have the Microsoft Graph Command Line Tools application created with the following permissions. After that you pass in the client secret into the `Connect-MgGraph` Authentication flow.

 I do not like this approach due to the fact that you're just throwing client secrets on a usb willy nilly, and if it were to get lost you would SOL and have to rotate the key, overall it's very insecure and risky to have those permissions on a usb somewhere. To nullify this I added the Connect-MgGraph with the following permissions as mentioned used in the app. Even if a user has an Intune Admin role though they would have to get consent the first time from a global admin since this is required, as the CLI tools have a different RBAC that has to go through manual approval. 

```
Device.ReadWrite.All
DeviceManagementManagedDevices.ReadWrite.All
DeviceManagementServiceConfig.ReadWrite.All
Group.ReadWrite.All
GroupMember.ReadWrite.All
```

Sources:

- `https://www.reddit.com/r/Intune/comments/147sjbx/comment/jnwrceh/`

- `https://learn.microsoft.com/en-us/entra/identity-platform/application-consent-experience`
