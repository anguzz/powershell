
'''
net stop wsearch
del "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.db"
net start wsearch
'''

try {
    Write-Host "Stopping the Windows Search service..."
    Stop-Service -Name "wsearch" -Force -ErrorAction Stop
    Write-Host "Windows Search service stopped successfully."
} catch {
    Write-Error "Failed to stop the Windows Search service. Error: $_"
    exit
}

try {
    $searchDbPath = "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.db"
    if (Test-Path $searchDbPath) {
        Remove-Item $searchDbPath -Force -ErrorAction Stop
        Write-Host "Windows Search database file deleted successfully."
    } else {
        Write-Warning "Windows Search database file not found."
    }
} catch {
    Write-Error "Failed to delete Windows Search database file. Error: $_"
    exit
}

try {
    Write-Host "Starting the Windows Search service..."
    Start-Service -Name "wsearch" -ErrorAction Stop
    Write-Host "Windows Search service started successfully."
} catch {
    Write-Error "Failed to start the Windows Search service. Error: $_"
    exit
}
