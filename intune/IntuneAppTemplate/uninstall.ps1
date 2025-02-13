# This script locates uninstaller files from a target installation directory and performs an uninstallation.

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$destinationPath = "C:\Installers\FolderNameHere"  # Specify the folder where installers are located from install.ps1

Start-Sleep -Seconds 5

# Uninstaller file configuration
$fileName = "uninstallFileExe.txt"  # Specify the uninstaller executable or MSI file name here
$filePath = Join-Path $destinationPath $fileName

# Command configurations for uninstallation
$uninstallCommand = '/uninstall /quiet /norestart'
$msiUninstallCommand = "msiexec.exe /x `"$filePath`" /quiet /norestart"

# Check for the presence of the file and uninstall
if (Test-Path -Path $filePath) {
    Write-Output "Uninstalling application from $filePath"
    if ($filePath -like "*.msi") {
        # Uninstall MSI package
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x `"$filePath`" /quiet /norestart" -Wait
    } else {
        # Uninstall using the executable
        Start-Process -FilePath $filePath -ArgumentList $uninstallCommand -Wait
    }
    Write-Output "Application uninstalled successfully"
} else {
    Write-Output "The file $filePath does not exist."
}
