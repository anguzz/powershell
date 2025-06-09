# --- Color Definitions ---
$ColorInfo    = "Cyan"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError   = "Red"
$ColorSection = "Magenta"
$ColorDebug   = "Gray"

Function Write-ColoredHost {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White",

        [Parameter(Mandatory=$false)]
        [string]$BackgroundColor = "Black"
    )
    Write-Host $Message -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
}

if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    try {
        Write-ColoredHost "Attempting to relaunch in 64-bit PowerShell for uninstallation..." -ForegroundColor $ColorInfo
        if ($env:PROCESSOR_ARCHITECTURE -ne "AMD64") {
            & "$env:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCommandPath
            exit $LASTEXITCODE
        } else {
            Write-ColoredHost "Already running in 64-bit PowerShell." -ForegroundColor $ColorInfo
        }
    }
    catch {
        Write-Error "Failed to start $PSCommandPath in 64-bit PowerShell for uninstallation. Error: $($_.Exception.Message)"
        throw "Failed to start $PSCommandPath in 64-bit PowerShell for uninstallation."
    }
}

$logFilePath = "C:\Temp\OutlookSignatureLog.txt" 
Start-Transcript -Path $logFilePath -Append 

Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "SCRIPT STARTED: Outlook Signature Manager Uninstallation (Manual User Path)" -ForegroundColor $ColorSection
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "Logging to $logFilePath" -ForegroundColor $ColorInfo
Write-ColoredHost "Current Date/Time: $(Get-Date)" -ForegroundColor $ColorInfo
Write-ColoredHost "Running as user: $(whoami)" -ForegroundColor $ColorInfo
Write-ColoredHost "PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor $ColorInfo
Write-ColoredHost "PowerShell Bitness: $(if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {'64-bit'} else {'32-bit'})" -ForegroundColor $ColorInfo
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-Host ""

Write-ColoredHost "[User Profile Detection for Signature Path]" -ForegroundColor $ColorSection
$currUser = $null
$userSignaturesPath = $null

try {
    Write-ColoredHost "Attempting to identify the active logged-in user (owner of explorer.exe)..." -ForegroundColor $ColorInfo
    $explorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe' AND SessionId = '$(Get-WmiObject win32_computersystem -Property UserName | Select-Object -ExpandProperty UserName | Split-Path -Leaf)\*'" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $explorerProcess) { 
         $explorerProcess = Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if ($explorerProcess) {
        $ownerInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwner -ErrorAction SilentlyContinue
        if ($ownerInfo -and $ownerInfo.User) {
            $currUser = $ownerInfo.User
            Write-ColoredHost "Identified active user: '$currUser' via explorer.exe process." -ForegroundColor $ColorSuccess
            $userSignaturesPath = "C:\Users\$currUser\AppData\Roaming\Microsoft\Signatures"
            Write-ColoredHost "Target user's Outlook Signatures folder set to: '$userSignaturesPath'" -ForegroundColor $ColorInfo
        } else {
            Write-ColoredHost "Could not retrieve owner information from explorer.exe process. User signatures path cannot be determined." -ForegroundColor $ColorError
        }
    } else {
        Write-ColoredHost "explorer.exe process not found or access denied. Cannot determine active user to build signatures path." -ForegroundColor $ColorError
        Write-ColoredHost "This script needs to identify the user to locate their Outlook signatures folder." -ForegroundColor $ColorError
    }
}
catch {
    Write-ColoredHost "An error occurred while trying to identify the active user: $($_.Exception.Message)" -ForegroundColor $ColorError
    Write-ColoredHost "User signatures path could not be determined due to this error." -ForegroundColor $ColorError
}
Write-Host ""

$scriptRootSignaturesSourcePath = Join-Path -Path $PSScriptRoot -ChildPath "Signatures"

Write-ColoredHost "[Outlook Signature File & Folder Removal]" -ForegroundColor $ColorSection

if (-not $userSignaturesPath) {
    Write-ColoredHost "User-specific signatures path could NOT be determined. Skipping removal of signature files and folders." -ForegroundColor $ColorError
} elseif (-not (Test-Path $userSignaturesPath)) {
    Write-ColoredHost "User's Outlook Signatures folder '$userSignaturesPath' does not exist. No signature files/folders to remove." -ForegroundColor $ColorInfo
} else {
    Write-ColoredHost "Confirmed user's Outlook Signatures folder exists at '$userSignaturesPath'." -ForegroundColor $ColorSuccess
    Write-ColoredHost "Source path for signature patterns: '$scriptRootSignaturesSourcePath'" -ForegroundColor $ColorInfo
    Write-ColoredHost "This script will use item names from the source folder to find and remove matching signatures." -ForegroundColor $ColorWarning
    Write-Host ""

    if (-not (Test-Path $scriptRootSignaturesSourcePath)) {
        Write-ColoredHost "The 'Signatures' subfolder (source for patterns) was NOT found at '$scriptRootSignaturesSourcePath'." -ForegroundColor $ColorError
        Write-ColoredHost "Cannot determine which signature patterns to remove from '$userSignaturesPath'." -ForegroundColor $ColorError
    } else {
        Write-ColoredHost "Found 'Signatures' subfolder. Reading items to create removal patterns..." -ForegroundColor $ColorInfo
        $sourceItems = Get-ChildItem -Path $scriptRootSignaturesSourcePath -ErrorAction SilentlyContinue

        if (-not $sourceItems) {
            Write-ColoredHost "No items found in the source 'Signatures' path. Cannot determine which signatures to remove." -ForegroundColor $ColorWarning
        } else {
            foreach ($itemInSource in $sourceItems) {
                $sourceItemName = $itemInSource.Name

                if ($itemInSource.PSIsContainer) {
                    $baseName = $sourceItemName -replace '_files$', ''
                    $wildcardPattern = "$baseName (*)_files"
                    Write-ColoredHost "Searching for directories matching pattern: '$wildcardPattern'" -ForegroundColor $ColorDebug
                    
                    $foldersToDelete = Get-ChildItem -Path $userSignaturesPath -Filter $wildcardPattern -Directory -ErrorAction SilentlyContinue
                    if ($foldersToDelete) {
                        foreach ($folder in $foldersToDelete) {
                            Write-ColoredHost "  Attempting to remove directory: '$($folder.FullName)'" -ForegroundColor $ColorInfo
                            try {
                                Remove-Item -Path $folder.FullName -Recurse -Force -ErrorAction Stop
                                Write-ColoredHost "  Successfully removed '$($folder.FullName)'." -ForegroundColor $ColorSuccess
                            } catch {
                                Write-ColoredHost "  Failed to remove '$($folder.FullName)'. Error: $($_.Exception.Message)" -ForegroundColor $ColorError
                            }
                        }
                    } else {
                        Write-ColoredHost "  No directories matching pattern '$wildcardPattern' were found." -ForegroundColor $ColorDebug
                    }
                } else {
                    # source file, e.g., "Standard.htm"
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sourceItemName)
                    $extension = $itemInSource.Extension
                    $wildcardPattern = "$baseName (*)$extension"
                    Write-ColoredHost "Searching for files matching pattern: '$wildcardPattern'" -ForegroundColor $ColorDebug

                    $filesToDelete = Get-ChildItem -Path $userSignaturesPath -Filter $wildcardPattern -File -ErrorAction SilentlyContinue
                    if ($filesToDelete) {
                        foreach ($file in $filesToDelete) {
                            Write-ColoredHost "  Attempting to remove file: '$($file.FullName)'" -ForegroundColor $ColorInfo
                            try {
                                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                                Write-ColoredHost "  Successfully removed '$($file.FullName)'." -ForegroundColor $ColorSuccess
                            } catch {
                                Write-ColoredHost "  Failed to remove '$($file.FullName)'. Error: $($_.Exception.Message)" -ForegroundColor $ColorError
                            }
                        }
                    } else {
                        Write-ColoredHost "  No files matching pattern '$wildcardPattern' were found." -ForegroundColor $ColorDebug
                    }
                }
                Write-Host "" # New line for readability
            }
        }
    }
}
Write-Host ""


# --- Uninstall Microsoft Graph Modules ---
<# 
Write-ColoredHost "[Microsoft Graph Module Uninstallation]" -ForegroundColor $ColorSection
$graphModulesToUninstall = @("Microsoft.Graph.Authentication", "Microsoft.Graph.Users")
Write-ColoredHost "Attempting to uninstall Microsoft Graph modules: $($graphModulesToUninstall -join ', ')" -ForegroundColor $ColorInfo
Write-ColoredHost "Note: This will attempt to uninstall modules for the scope in which they were installed (AllUsers or CurrentUser)." -ForegroundColor $ColorInfo
Write-Host ""

foreach ($moduleName in $graphModulesToUninstall) {
    Write-ColoredHost "Checking if module '$moduleName' is installed..." -ForegroundColor $ColorDebug
    try {
        # Get-InstalledModule can find modules in any scope
        $installedModule = Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue
        
        if ($installedModule) {
            Write-ColoredHost "Module '$moduleName' is installed (Version: $($installedModule.Version), Scope: $($installedModule.InstalledLocation)). Attempting to uninstall..." -ForegroundColor $ColorInfo
            try {
                Uninstall-Module -Name $moduleName -AllVersions -Force -Confirm:$false -ErrorAction Stop
                Write-ColoredHost "Successfully uninstalled module '$moduleName'." -ForegroundColor $ColorSuccess
            }
            catch {
                Write-ColoredHost "Failed to uninstall module '$moduleName'. Error: $($_.Exception.Message)" -ForegroundColor $ColorWarning
                Write-ColoredHost "You may need to remove it manually or check permissions. Ensure no PowerShell sessions are currently using the module." -ForegroundColor $ColorWarning
            }
        } else {
            Write-ColoredHost "Module '$moduleName' is not installed. Skipping." -ForegroundColor $ColorDebug
        }
    }
    catch {
        Write-ColoredHost "Could not check or uninstall module '$moduleName'. Error: $($_.Exception.Message)" -ForegroundColor $ColorWarning
    }
    Write-Host "" 
}
Write-Host ""
#>

# --- Cleanup Original Install Log ---
Write-ColoredHost "[Cleanup This Uninstallation Script's Log (Optional)]" -ForegroundColor $ColorSection
Write-ColoredHost "The log for this uninstallation session is at: $logFilePath" -ForegroundColor $ColorInfo
Write-ColoredHost "This script does not automatically delete its own log file upon completion." -ForegroundColor $ColorInfo
$installTimeLogFile = "C:\Temp\OutlookSignatureLog.txt"
Write-ColoredHost "If you wish to clean up the main log file at '$installTime_logFile', do so manually." -ForegroundColor $ColorInfo
Write-ColoredHost "This script will not delete it automatically to preserve records." -ForegroundColor $ColorInfo
Write-Host ""


Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "SCRIPT FINISHED: Outlook Signature Manager Uninstallation" -ForegroundColor $ColorSection
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Stop-Transcript