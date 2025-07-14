# DSRegCMD Logger Script

This PowerShell script collects device registration information using `dsregcmd /status` and then refreshes the Primary Refresh Token (PRT) using `dsregcmd /refreshprt`.

## What It Does

1. Creates a log directory at `C:\logs\dsregcmd` if it doesn't exist.
2. Runs `dsregcmd /status` and saves the output to a timestamped log file.
3. Runs `dsregcmd /refreshprt` to refresh the device's PRT.

## Usage

1. Open PowerShell as Administrator.
2. Run the script:
   ```powershell
   .\dsreg_logger.ps1


