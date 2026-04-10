# detect if one launch is installed 

$found = $false

$paths = @(
    "C:\Users\*\AppData\Local\OneLaunch", 
    "C:\WINDOWS\Prefetch\ONELAUNCH-*.pf"  
)

foreach ($path in $paths) {
    $resolvedPaths = Resolve-Path $path -ErrorAction SilentlyContinue
    foreach ($resolvedPath in $resolvedPaths) {
        if (Test-Path $resolvedPath) {
            Write-Output "OneLaunch remnant found at: $resolvedPath"
            $found = $true
        }
    }
}

#if either is found we remove onelaunch
$registryPaths = @(
    "HKCU:\Software\Classes\*\onelaunch*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UFH\SHC\*onelaunch*"
    
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        Write-Output "OneLaunch registry entry found at: $regPath"
        $found = $true
    }
}

$tasks = @(
    "OneLaunchLaunchTask",
    "OneLaunchUpdateTask"
)

foreach ($task in $tasks) {
    $taskPath = "C:\Windows\System32\Tasks\$task"
    if (Test-Path $taskPath) {
        Write-Output "OneLaunch task found at: $taskPath"
        $found = $true
    }
}


if ($found) {
    Write-Output "OneLaunch remnants detected. Remediation required."
    exit 1  
} else {
    Write-Output "No OneLaunch remnants detected."
    exit 0 
}
