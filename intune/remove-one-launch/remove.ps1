

# kill processes that use one launch
$processNames = @("onelaunch", "onelaunchtray", "chromium", "ChromiumStartupProxy", "OneLaunch - Package Track*")
foreach ($name in $processNames) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# uninstall 
$applications = Get-ChildItem HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall,
               HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
               Get-ItemProperty | Where-Object { $_.DisplayName -like "*OneLaunch*" }

foreach ($app in $applications) {
    $uninstallString = $app.UninstallString
    if ($uninstallString) {
        Start-Process cmd -ArgumentList "/c $uninstallString /quiet /norestart" -Wait
    }
}

# get rid of user-specific files and shortcuts
$user_list = Get-Item C:\users\* | Select-Object -ExpandProperty Name
foreach ($user in $user_list) {
    $installers = @(Get-ChildItem C:\users\$user -Recurse -Filter "OneLaunch*.exe" | ForEach-Object { $_.FullName })
    foreach ($install in $installers) {
        Remove-Item $install -ErrorAction SilentlyContinue
    }
    $shortcuts = @(
        "C:\Users\$user\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\OneLaunch.lnk",
        "C:\Users\$user\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\OneLaunchChromium.lnk",
        "C:\Users\$user\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\OneLaunchUpdater.lnk",
        "C:\Users\$user\Desktop\OneLaunch.lnk",
        "C:\Users\$user\OneDrive\Desktop\OneLaunch.lnk"
    )
    foreach ($shortcut in $shortcuts) {
        Remove-Item $shortcut -ErrorAction SilentlyContinue
    }
    $localPaths = @(
        "C:\Users\$user\Appdata\Local\OneLaunch",
        "C:\Users\$user\Appdata\Roaming\Microsoft\Windows\Start Menu\Programs\OneLaunch"
    )
    foreach ($localPath in $localPaths) {
        Remove-Item $localPath -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# clean up reg
$sid_list = Get-ChildItem -Path Registry::HKU\* -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'S-\d-(?:\d+-){5,14}\d+$' }
foreach ($sid in $sid_list) {
    $paths = @(
        "Software\Microsoft\Windows\CurrentVersion\Uninstall\{4947c51a-26a9-4ed0-9a7b-c21e5ae0e71a}_is1",
        "Software\Microsoft\Windows\CurrentVersion\Run\OneLaunch",
        "Software\Microsoft\Windows\CurrentVersion\Run\OneLaunchChromium",
        "Software\Microsoft\Windows\CurrentVersion\Run\GoogleChromeAutoLaunch*",
        "Software\OneLaunch",
        "SOFTWARE\Classes\OneLaunchHTML",
        "SOFTWARE\RegisteredApplications"
    )
    foreach ($path in $paths) {
        $regPath = "Registry::$sid\$path"
        Remove-Item $regPath -Recurse -ErrorAction SilentlyContinue -Force
    }
}

# remove scheduled tasks and task cache entries
$tasks = @("OneLaunchLaunchTask", "ChromiumLaunchTask", "OneLaunchUpdateTask")
foreach ($task in $tasks) {
    $taskPath = "C:\Windows\System32\Tasks\$task"
    Remove-Item $taskPath -ErrorAction SilentlyContinue
    $taskCachePath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\TREE\$task"
    Remove-Item -Path Registry::$taskCachePath -Recurse -ErrorAction SilentlyContinue
}

# remove trace cache keys
$traceCacheKeys = @(
    "HKLM\SOFTWARE\Microsoft\Tracing\onelaunch_RASMANCS",
    "HKLM\SOFTWARE\Microsoft\Tracing\onelaunch_RASAPI32"
)
foreach ($traceCacheKey in $traceCacheKeys) {
    Remove-Item -Path Registry::$traceCacheKey -Recurse -ErrorAction SilentlyContinue
}
