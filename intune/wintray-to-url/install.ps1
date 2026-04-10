# SCRIPT: install.ps1
# PURPOSE: Installs the tray application and creates a scheduled task to run it on logon.
# NOTE: This script must be run as an Administrator.

# --- CONFIGURATION ---
# The Display name of your app. Used for the folder name and scheduled task.
$AppName       = "Anguzz github tray"
# The name of the .exe file created by ps2exe. Do not change unless you rename file
$SourceExeName = "tray_app.exe"

$targetDir = "C:\Program Files\$AppName"

# --- END CONFIGURATION ---

# Construct paths
$destExePath = Join-Path $targetDir $SourceExeName

# Create the installation directory
if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force
}

# Copy the compiled .exe file to the installation directory
Copy-Item "$PSScriptRoot\$SourceExeName" -Destination $destExePath -Force
Write-Host "Application file copied to $destExePath"

# --- SCHEDULED TASK SETUP ---

# 1. Define the Action to run the .exe file directly.
$Action = New-ScheduledTaskAction -Execute $destExePath

# 2. Define the Trigger to run when any user logs on.
$Trigger = New-ScheduledTaskTrigger -AtLogOn

# 3. Define the Settings for a persistent application.
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

# 4. Define the Principal to run as a standard user.
$Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel 'Limited'

# 5. Register the task with the system.
Register-ScheduledTask -TaskName $AppName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force
Write-Host "Scheduled task '$AppName' has been created."



# --- IMMEDIATE 1st time LAUNCH (HEADLESS) ---

Write-Host "Starting the application for the current user using conhost.exe..."
Start-Process -FilePath "conhost.exe" -ArgumentList "--headless `"$destExePath`""


Write-Host "Installation complete. The application is now running."
