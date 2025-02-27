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

$fileName = "example.exe"  # add EXE file name here
$filePath = Join-Path $destinationPath $fileName


# generic EXE installation command
# check what flags are supported by the exe /help or ?help /h, etc
$installCommand = "/install /quiet /norestart"

if (Test-Path -Path $filePath) {
    Write-Output "Installing EXE from $filePath"
    Start-Process -FilePath $filePath -ArgumentList $installCommand -Wait
    Write-Output "EXE application installed successfully"
} else {
    Write-Output "The EXE file $filePath does not exist."
}
