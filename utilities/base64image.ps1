#base 64s image and copies the data url to clipboard for usage html src

$imagePath = "C:\image.png" # Change this to your image path

$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($imagePath))

$fullDataUri = "data:image/png;base64,$base64"

$fullDataUri | Set-Clipboard

Write-Output -InputObject "Base64 image tag src copied to clipboard." -WarningAction SilentlyContinue
