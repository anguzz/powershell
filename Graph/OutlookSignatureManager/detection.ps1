$currUser = (Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue |
    Select-Object -First 1 |
    ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName GetOwner -ErrorAction SilentlyContinue }).User


$path = "C:\Users\$currUser\AppData\Roaming\Microsoft\Signatures\Standard_files"

if (Test-Path $path) {
    Write-output "Path found, email signature detected"

    exit 0  
} else {
    Write-output "Path not found, email signature not detected"
    exit 1 
}
