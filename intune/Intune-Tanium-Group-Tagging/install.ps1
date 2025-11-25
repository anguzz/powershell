$tagPath = "HKLM:\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags"
$tagName = "tag-name-here"

# Build Tanium-style timestamp value
$timestamp = "Added: $(Get-Date -Format 'M/d/yyyy h:mm:ss tt')"

# Ensure the Tag directory exists
if (-not (Test-Path $tagPath)) {
    New-Item -Path $tagPath -Force | Out-Null
}

# Create or update the registry value
try {
    New-ItemProperty -Path $tagPath -Name $tagName -PropertyType String -Value $timestamp -Force | Out-Null
    Write-Output "Tag '$tagName' created with timestamp '$timestamp'."
}
catch {
    Write-Output "Error creating tag '$tagName' : $_"
}

Write-Output "Tanium tag script completed."
exit 0
