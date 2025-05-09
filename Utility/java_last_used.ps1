

$javaExecutables = @("JAVAWS.EXE", "JAVA.EXE", "JAVAW.EXE")

# reg path for tracking
$registryPath = "HKLM:\SOFTWARE\JavaTracking"

# check the registry path exists
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force
}

# start a variable to store the most recent usage
$mostRecentUse = $null
$mostRecentExecutable = $null

foreach ($javaExecutable in $javaExecutables) {
    # define path to prefetch default location
    $prefetchFilePath = "C:\Windows\Prefetch\$javaExecutable-*.pf"

    # find  file
    $prefetchFile = Get-ChildItem -Path $prefetchFilePath -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($prefetchFile -and ($null -eq $mostRecentUse -or $prefetchFile.LastWriteTime -gt $mostRecentUse)) {
        $mostRecentUse = $prefetchFile.LastWriteTime
        $mostRecentExecutable = $javaExecutable
    }
}

if ($mostRecentUse) {
    Write-Output "Most recently used Java executable: $mostRecentExecutable with last use on $mostRecentUse"
    Set-ItemProperty -Path $registryPath -Name "LastUsed" -Value $mostRecentUse.ToString()

    $currentDate = Get-Date
    $timeSpan = New-TimeSpan -Start $mostRecentUse -End $currentDate

    # check most recents java executable to see if it was used in last 30 days
    if ($timeSpan.Days -le 30) {
        Set-ItemProperty -Path $registryPath -Name "UsedInLast30Days" -Value "Yes"
    } else {
        Set-ItemProperty -Path $registryPath -Name "UsedInLast30Days" -Value "No"
    }
} else {
    Write-Output "No Prefetch files found for any Java executable."
    Set-ItemProperty -Path $registryPath -Name "LastUsed" -Value $null
    Set-ItemProperty -Path $registryPath -Name "UsedInLast30Days" -Value "No"
}
