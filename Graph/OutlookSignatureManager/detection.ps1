$currUser = (Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue |
    Select-Object -First 1 |
    ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName GetOwner -ErrorAction SilentlyContinue }).User

if (-not $currUser) {
    Write-Output "User not found, cannot check for signature"
    exit 1
}

# Check for the .htm file instead of the folder and also wildcard for the file name since we are including email extension per user on the file
$wildcardPath = "C:\Users\$currUser\AppData\Roaming\Microsoft\Signatures\Standard (*).htm"

if (Test-Path $wildcardPath) {
    Write-Output "Signature file found, email signature detected"
    exit 0
} else {
    Write-Output "Signature file not found, email signature not detected"
    exit 1
}