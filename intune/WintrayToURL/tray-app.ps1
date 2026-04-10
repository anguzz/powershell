# SCRIPT: tray_app.ps1
# PURPOSE: A persistent tray application that opens a URL.
#          Designed to be compiled into a true windowless .EXE file.

# --- CONFIGURATION ---
$AppName  = "anguzz Github"
$Url      = "https://github.com/anguzz"
$MenuText = "Open Github"
# --- END CONFIGURATION ---

# Load required .NET assemblies for the GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- CREATE TRAY ICON AND MENU ---

# Create the NotifyIcon object (the tray icon itself)
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon

# This line extracts the icon from the .EXE file itself after compilation
$notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon([System.Windows.Forms.Application]::ExecutablePath)

$notifyIcon.Text    = $AppName
$notifyIcon.Visible = $true

# Create the right-click context menu
$contextMenu = New-Object System.Windows.Forms.ContextMenu
$menuItem    = New-Object System.Windows.Forms.MenuItem $MenuText, { Start-Process $Url }
$exitItem    = New-Object System.Windows.Forms.MenuItem "Exit", {
    $notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
}

# Add items to the menu and link it to the icon
# We use [void] to suppress the output of the .Add() method
[void]$contextMenu.MenuItems.Add($menuItem)
[void]$contextMenu.MenuItems.Add($exitItem)
$notifyIcon.ContextMenu = $contextMenu

# Define the action for a single LEFT-click on the icon
$notifyIcon.Add_Click({
    # This makes the left-click do the same thing as the main right-click option
    Start-Process $Url
})

# --- RUN THE APPLICATION ---
# This creates a message loop to keep the script running and responsive.
[System.Windows.Forms.Application]::Run()