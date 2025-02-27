$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sourcePath = Join-Path $scriptPath "Files"

# change these variables based on your EXE install
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

Start-Sleep -Seconds 5

$fileName = "example.msi"  # add the MSI file name here
$filePath = Join-Path $destinationPath $fileName



#  check for MSI file in Files folder and install
if (Test-Path -Path $filePath) {
    Write-Output "Installing MSI from $filePath"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filePath`" /quiet /norestart" -Wait
    Write-Output "MSI application installed successfully"
} else {
    Write-Output "The MSI file $filePath does not exist."
}
