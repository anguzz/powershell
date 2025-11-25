$tagPath = "HKLM:\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags" # this tag localtion is used on single endpoint view in the tanium console, it will appear in the UI under Tags section for the endpoint.
$tagName = "tag-name-here" # add reg value for site here.

# If key doesn’t exist, nothing to remove
if (-not (Test-Path $tagPath)) {
    Write-Output "Tag path missing. Nothing to uninstall."
    exit 0
}

try {
    # Check if tag exists
    $tagValue = Get-ItemProperty -Path $tagPath -Name $tagName -ErrorAction SilentlyContinue

    if ($tagValue) {
        # Remove only the tag, leave the Tags key intact
        Remove-ItemProperty -Path $tagPath -Name $tagName -Force
        Write-Output "Tag '$tagName' removed successfully."
    }
    else {
        Write-Output "Tag '$tagName' not found. Nothing to uninstall."
    }
}
catch {
    Write-Output "Failed to remove tag '$tagName': $_"
    exit 1
}

exit 0
