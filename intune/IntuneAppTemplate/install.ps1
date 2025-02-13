$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sourcePath = Join-Path $scriptPath "Files"

# Configure these variables based on your exe/msi name
$installerFolderName = "FolderNameHere"
$destinationPath = "C:\Installers\$installerFolderName"


if (-Not (Test-Path -Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory -Force
}

if (Test-Path -Path $sourcePath) {
    Write-Output "Copying files from $sourcePath to $destinationPath"
    Copy-Item -Path "$sourcePath\*" -Destination $destinationPath -Force
} else {
    Write-Output "Source path $sourcePath does not exist."
    exit
}

# Delay to ensure file operations complete
Start-Sleep -Seconds 5

# Installer file configuration
$fileName = "example.txt"  # Add the appropriate executable or MSI file name here
$filePath = Join-Path $destinationPath $fileName

# Command configurations
$installCommand = '/install /quiet /norestart'
$msiInstallCommand = "msiexec.exe /i `"$filePath`" /quiet /norestart"

# Check for the presence of the file and install
if (Test-Path -Path $filePath) {
    Write-Output "Installing from $filePath"
    if ($filePath -like "*.msi") {
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filePath`" /quiet /norestart" -Wait
    } else {
        Start-Process -FilePath $filePath -ArgumentList $installCommand -Wait
    }
    Write-Output "Application installed successfully"
} else {
    Write-Output "The file $filePath does not exist."
}

