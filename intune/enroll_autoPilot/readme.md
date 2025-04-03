# AutoPilot Enrollment and Hash Generator

This PowerShell script provides a simple interface for enrolling devices into Windows Autopilot and generating Autopilot hardware hashes. It is designed to automate the generation and transfer of the hardware hash file, simplifying the device enrollment process for system administrators.

## Overview

Currently, when a new device during the out-of-box experience (OOBE) needs to be enrolled in Autopilot, a desktop support technician manually intervenes by using a shell (accessible via Shift+Fn+F10) to execute PowerShell commands or run a script. The script, generates a CSV hash file which then must be manually copied onto a USB drive by the technician. This hash file then has to be uploaded to intune 

To simplify this process, we aim to automate the generation of the CSV file and its transfer to and from the USB drive. The script enhances the operational efficiency by reducing manual intervention and minimizing the risk of human error.

## Solution

The goal is to create an interactive shell program that automates some of these processes. Specifically, when a USB drive is plugged into a device, the PowerShell script will automatically run, generating the CSV into that same USB. The script will also provide options to handle the copying of any existing hash back to the device safely and securely.

### Core Functionality

At its core, this package is meant for a USB drive to handle the generation of a CSV file using core commands, and facilitate the moving back and forth between the target device (where the hash.csv file is generated) and the host device (where the file will be uploaded to Intune).

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

