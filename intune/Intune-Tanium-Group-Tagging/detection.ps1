# for a remediation detection simply change the whole script to exit 1; to force the tag to be applied

$tagPath = "HKLM:\SOFTWARE\Tanium\Tanium Client\Sensor Data\Tags\"
$tagName = "Tag-name-here" # add reg value for site here.

# Check if path exists
if (-not (Test-Path $tagPath)) {
    # Tag store missing > app not installed
    exit 1
}

# Get the value if present
try {
    $value = Get-ItemProperty -Path $tagPath -Name $tagName -ErrorAction Stop

    if ($value.$tagName -eq "True") {
        # Tag exists > app is installed
        Write-Output "Tag '$tagName' found. Application is installed."
        exit 0
        
    }
    else {
        Write-output "Tag '$tagName' not found. Application is not installed."
        exit 1
    }
}
catch {
    # Value missing > not installed
    Write-output "Tag '$tagName' not found. Application is not installed."
    exit 1
}
