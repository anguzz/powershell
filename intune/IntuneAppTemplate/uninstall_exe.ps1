
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

$destinationPath = "C:\Installers\FolderNameHere"  # Specify the folder where installers are located from install.ps1

Start-Sleep -Seconds 5

# Uninstaller file configuration
$fileName = "uninstallFile.exe"  # Specify the installer executable file name here
$filePath = Join-Path $destinationPath $fileName

# Command configuration for uninstallation
$uninstallCommand = '/uninstall /quiet /norestart'

# Check for the presence of the executable file and uninstall
if (Test-Path -Path $filePath) {
    Write-Output "Uninstalling application from $filePath"
    # Uninstall using the executable
    Start-Process -FilePath $filePath -ArgumentList $uninstallCommand -Wait
    Write-Output "Application uninstalled successfully"
} else {
    Write-Output "The uninstaller file $filePath does not exist."
}
