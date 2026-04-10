$keyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.WAU.Notification"
$valueName = "ShowBanner"

try {
    $keyValue = Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction Stop
    if ($null -ne $keyValue) {
        Write-Host "The DWORD value 'ShowBanner' exists with value: $($keyValue.ShowBanner)"
        Exit 0  
    }
} catch {
    Write-Host "The key or value does not exist."
    Exit 1  
}
