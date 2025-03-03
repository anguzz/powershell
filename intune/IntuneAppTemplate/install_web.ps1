#performs install from web download, extracts folder, starts msi process and cleans up downloaded folders. 

$downloadUrl = "https://downloadsite.com"
$downloadPath = "C:\Installers\DownloadedApp"
$zipFilePath = Join-Path $downloadPath "download.zip"
$extractPath = Join-Path $downloadPath "Extracted"

# Create the directory if it doesn't exist
if (-not (Test-Path $downloadPath)) {
    New-Item -Path $downloadPath -ItemType Directory
}

# Download the latest ZIP file
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFilePath

# Extract the ZIP file
Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force

# Find the MSI file in the extracted directory
$msiFilePath = Get-ChildItem -Path $extractPath -Filter *.msi -Recurse | Select-Object -ExpandProperty FullName

# Install the MSI file
Start-Process "msiexec.exe" -ArgumentList "/i `"$msiFilePath`" /qn" -Wait -NoNewWindow

# cleans up 
Remove-Item -Path $zipFilePath
Remove-Item -Path $extractPath -Recurse
