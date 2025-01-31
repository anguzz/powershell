# Bypass the execution policy for this session
# Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Get the username from environment variable
$username = [Environment]::UserName

# Set the path to the Teams background folder
$destinationPath = "C:\Users\$username\AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\Backgrounds\Uploads"

# makes the destination directory if it does not exist
if (-Not (Test-Path -Path $destinationPath)) {
    New-Item -Path $destinationPath -ItemType Directory -Force
}

# Define the source path where the images are stored (modify as necessary)
$scriptPath = (Split-Path -Parent $MyInvocation.MyCommand.Definition)
$sourcePath = Join-Path $scriptPath "bg_images" # Assuming images are in a in same dir folder named 'bg_images'

# Check if source path exists
if (Test-Path -Path $sourcePath) {
    try {
        Copy-Item -Path "$sourcePath\*" -Destination $destinationPath -Force
    } catch {
        #Write-Output "Error copying files: $_"
        exit
    }
} else {
   # Write-Output "Source path $sourcePath does not exist."
    exit
}
