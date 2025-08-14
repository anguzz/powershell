# Define the target version for comparison
$targetVersion = "" # Replace this with the desired target version



# Define potential paths for TeamViewer.exe to support both 32-bit and 64-bit systems
$possiblePaths = @(
    (Join-Path -Path $env:ProgramFiles -ChildPath 'TeamViewer\TeamViewer.exe'),
    (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'TeamViewer\TeamViewer.exe')
)

# Find the first path that actually exists
$filePath = $possiblePaths | Where-Object { Test-Path $_ } | Select-Object -First 1



# Function to normalize and convert version strings to [Version] objects for reliable comparison
function Normalize-Version ($version) {
    # Replaces any dashes with dots to ensure the string can be cast to a [Version] object
    $normalized = $version -replace '-', '.'
    return [Version]$normalized
}

# Check if the file was found in any of the possible locations
if ($filePath) {
    Write-Output "Found TeamViewer at: $filePath"
    
    # Get the raw file version from the executable's metadata
    $fileVersionRaw = (Get-Item -Path $filePath).VersionInfo.FileVersion
    Write-Output "Detected file version: $fileVersionRaw"

    # Normalize both the detected version and the target version for comparison
    $fileVersion = Normalize-Version $fileVersionRaw
    $target = Normalize-Version $targetVersion

    # Compare the versions for an exact match
    if ($fileVersion -eq $target) {
        Write-Output "Version matches exactly. ($targetVersion)"
        exit 0
    } else {
        Write-Output "Version mismatch. Expected: $targetVersion, Found: $fileVersionRaw"
        exit 1
    }
} else {
    # If the file was not found in any of the standard locations, report an error
    Write-Output "File not found: Could not locate TeamViewer.exe in standard directories."
    exit 1
}
