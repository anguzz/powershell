# Define the file path and target version
# detection script to ensure app is installed on a specific file
$filePath = "C:\Program Files\PathtoApp"
$targetVersion = "1.0"  # Replace this with the desired target version

# Function to compare two version numbers
function Compare-Version ($version1, $version2) {
    # Clean the version string by replacing dashes with dots and ensuring a proper format
    $version1 = $version1 -replace '-', '.'  # Replace dash with dot

    # Ensure that both versions are well-formed for comparison
    $v1 = [Version]$version1
    $v2 = [Version]$version2
    return $v1.CompareTo($v2)
}

# Check if the file exists
if (Test-Path -Path $filePath) {
    # Get the file version using FileVersion instead of ProductVersionRaw
    $fileVersion = (Get-Item -Path $filePath).VersionInfo.FileVersion
    Write-Output "Detected file version installed on computer: $fileVersion"

    # Compare the file version with the target version
    if ((Compare-Version $fileVersion $targetVersion) -ge 0) {
        Write-Output "Detected version $fileVersion matches requirement"
        exit 0  # File version is equal to or higher than target
    } else {
        Write-Output "Version $fileVersion is lower than the required target version: $targetVersion"
        exit 1  # File version is lower than target
    }
} else {
    Write-Output "File not found: $filePath"
    exit 1  # File not found
}
