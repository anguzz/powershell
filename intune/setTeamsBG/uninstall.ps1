
$username = [Environment]::UserName

$destinationPath = "C:\Users\$username\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"

# sourcepath (assuming script is run from the same directory where bg_images folder is)
$scriptPath = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$sourcePath = Join-Path $scriptPath "bg_images"

# Retrieve all image files in the source directory
$images = Get-ChildItem -Path $sourcePath -File

# loops through each image and remove it from the teams destination path
foreach ($image in $images) {
    $fullPath = Join-Path $destinationPath $image.Name
    if (Test-Path -Path $fullPath) {
        Remove-Item -Path $fullPath -Force
        Write-Output "Removed image: $fullPath"
    } else {
        Write-Output "Image not found: $fullPath"
    }
}
