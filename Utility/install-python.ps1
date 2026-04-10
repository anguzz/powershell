Write-Output "=== Disabling Microsoft Store Python aliases ==="

# Remove App Execution Aliases (stops store redirect)
$aliasPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppInstaller\Aliases"
foreach ($exe in @("python.exe", "python3.exe")) {
    $fullPath = Join-Path $aliasPath $exe
    if (Test-Path $fullPath) {
        Remove-Item $fullPath -Force
        Write-Output "Removed alias: $exe"
    }
}

# Remove WindowsApps python shims
Write-Output "Removing WindowsApps Python stubs..."
$stubPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\"
Get-ChildItem $stubPath -Filter "python*.exe" -ErrorAction SilentlyContinue | Remove-Item -Force

Write-Output "=== Installing Python from python.org ==="

$pythonVersion = "3.14.2"
$installer = "$env:TEMP\python-$pythonVersion-amd64.exe"
$downloadUrl = "https://www.python.org/ftp/python/$pythonVersion/python-$pythonVersion-amd64.exe"

Invoke-WebRequest -Uri $downloadUrl -OutFile $installer
Write-Output "Downloaded Python $pythonVersion"

# Install silently, add to PATH automatically
Start-Process -FilePath $installer -ArgumentList `
    "/quiet InstallAllUsers=1 PrependPath=1 Include_test=0" -Wait

Write-Output "Python installation completed."

Write-Output "=== Ensuring Python is in PATH ==="

$pythonDir = "C:\Users\$env:USERNAME\AppData\Local\Programs\Python\Python314\"

if (-Not ($env:PATH -like "*$pythonDir*")) {
    [Environment]::SetEnvironmentVariable(
        "PATH",
        $env:PATH + ";$pythonDir",
        "User"
    )
    Write-Output "Added Python 3.14 directory to PATH."
} else {
    Write-Output "Python PATH already configured."
}

Write-Output "=== Finished. Open a new terminal and run 'python --version' ==="
