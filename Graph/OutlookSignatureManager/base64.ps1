$imagePath = "graph\EmailSignatureTemplate\26943671.png"

# Read file and convert to Base64
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($imagePath))

# Add the proper data URI prefix
$fullDataUri = "data:image/png;base64,$base64"

# Copy to clipboard
$fullDataUri | Set-Clipboard

Write-Output -InputObject "Base64 image tag src copied to clipboard." -WarningAction SilentlyContinue

