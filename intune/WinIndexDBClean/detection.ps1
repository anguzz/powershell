
$windowsSearchDbPath = "C:\ProgramData\Microsoft\Search\Data\Applications\Windows\Windows.db"

$sizeThreshold = 10GB 
 
if (Test-Path $windowsSearchDbPath) {
    $fileSize = (Get-Item $windowsSearchDbPath).Length

    if ($fileSize -gt $sizeThreshold) {
        Write-Host "The Windows Search index database size ($fileSize bytes) exceeds the threshold of $sizeThreshold bytes."
        exit 1 #takes action if exceeded
    } else {
        Write-Host "The Windows Search index database size ($fileSize bytes) is below the threshold of $sizeThreshold bytes."
        exit 0
    }
} else {
    Write-Warning "Windows Search index database file does not exist at the path: $windowsSearchDbPath"
    exit 0
}
