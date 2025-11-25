# Run script as 32-bit process on 64-bit clients: Yes

$tagPath = "HKLM:\SOFTWARE\WOW6432Node\Tanium\Tanium Client\Sensor Data\Tags"
$tagName = "Tag-name-here"

# Check if parent key exists
if (-not (Test-Path $tagPath)) {
    Write-Output "Tag path missing. Not installed."
    exit 1
}

try {
    # Try to read the value
    $value = (Get-ItemProperty -Path $tagPath -Name $tagName -ErrorAction Stop).$tagName

    if ($value -match "^Added:") {
        Write-Output "Tag '$tagName' found with timestamp '$value'. Installed."
        exit 0
    }
    else {
        Write-Output "Tag '$tagName' value not in expected format. Not installed."
        exit 1
    }
}
catch {
    Write-Output "Tag '$tagName' not found. Not installed."
    exit 1
}
