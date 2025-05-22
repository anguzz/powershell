
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
$userSignaturesPath = $null # Initialize to null

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
    Write-ColoredHost "This usually means the script could not identify the logged-in user who owns explorer.exe." -ForegroundColor $ColorError
} elseif (-not (Test-Path $userSignaturesPath)) {
    Write-ColoredHost "User's Outlook Signatures folder '$userSignaturesPath' does not exist. No signature files/folders to remove from this path." -ForegroundColor $ColorInfo
} else {
    Write-ColoredHost "Confirmed user's Outlook Signatures folder exists at '$userSignaturesPath'." -ForegroundColor $ColorSuccess
    Write-ColoredHost "Source path for signature item names (from deployment package): '$scriptRootSignaturesSourcePath'" -ForegroundColor $ColorInfo
    Write-ColoredHost "This script expects '$scriptRootSignaturesSourcePath' to contain items with the *exact names* of signatures/assets to be removed." -ForegroundColor $ColorWarning
    Write-Host ""

    if (-not (Test-Path $scriptRootSignaturesSourcePath)) {
        Write-ColoredHost "The 'Signatures' subfolder (source list) was NOT found at '$scriptRootSignaturesSourcePath'." -ForegroundColor $ColorError
        Write-ColoredHost "This script relies on that folder to know which signature items to remove." -ForegroundColor $ColorError
        Write-ColoredHost "No signature items will be removed from '$userSignaturesPath' without this source list." -ForegroundColor $ColorError
    } else {
        Write-ColoredHost "Found the 'Signatures' subfolder at '$scriptRootSignaturesSourcePath'. Reading items to be deleted..." -ForegroundColor $ColorInfo
        $deployedItems = Get-ChildItem -Path $scriptRootSignaturesSourcePath -ErrorAction SilentlyContinue

        if (-not $deployedItems) {
            Write-ColoredHost "No items (files or folders) found in the source 'Signatures' path '$scriptRootSignaturesSourcePath'." -ForegroundColor $ColorWarning
            Write-ColoredHost "Cannot determine which specific signatures to remove from '$userSignaturesPath'." -ForegroundColor $ColorWarning
        } else {
            Write-ColoredHost "Attempting to remove the following items (if they exist) from '$userSignaturesPath':" -ForegroundColor $ColorInfo
            $deployedItems | ForEach-Object { Write-ColoredHost "- $($_.Name)" -ForegroundColor $ColorInfo }
            Write-Host ""

            foreach ($itemInSource in $deployedItems) {
                $itemName = $itemInSource.Name
                $targetItemPathInUserSignatures = Join-Path -Path $userSignaturesPath -ChildPath $itemName
                
                Write-ColoredHost "Processing '$itemName' (from source folder):" -ForegroundColor $ColorDebug
                if (Test-Path $targetItemPathInUserSignatures) {
                    Write-ColoredHost "  Attempting to remove: '$targetItemPathInUserSignatures'" -ForegroundColor $ColorInfo
                    try {
                        Remove-Item -Path $targetItemPathInUserSignatures -Recurse -Force -ErrorAction Stop
                        Write-ColoredHost "  Successfully removed '$targetItemPathInUserSignatures'." -ForegroundColor $ColorSuccess
                    }
                    catch {
                        Write-ColoredHost "  Failed to remove '$targetItemPathInUserSignatures'. Error: $($_.Exception.Message)" -ForegroundColor $ColorError
                    }
                } else {
                    Write-ColoredHost "  Item '$itemName' not found in the user's signatures folder ('$targetItemPathInUserSignatures'). Skipping." -ForegroundColor $ColorDebug
                }
                Write-Host "" 
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
Write-ColoredHost "Note: Modules will be uninstalled for the CurrentUser scope if found." -ForegroundColor $ColorInfo
Write-Host ""

foreach ($moduleName in $graphModulesToUninstall) {
    Write-ColoredHost "Checking if module '$moduleName' is installed for CurrentUser..." -ForegroundColor $ColorDebug
    try {
        # Check if the module is installed for the current user (which might be SYSTEM if run by Intune)
        # If modules were installed with -Scope CurrentUser during install, this needs to run in user context for uninstall,
        # or the install script needs to install for AllUsers if Intune runs install as SYSTEM.
        # For now, assuming it tries to uninstall from scope CurrentUser (effective user running the script).
        $installedModule = Get-InstalledModule -Name $moduleName -Scope CurrentUser -ErrorAction SilentlyContinue
        
        if ($installedModule) {
            Write-ColoredHost "Module '$moduleName' is installed (Version: $($installedModule.Version)) in CurrentUser scope. Attempting to uninstall..." -ForegroundColor $ColorInfo
            try {
                Uninstall-Module -Name $moduleName -AllVersions -Force -Confirm:$false -ErrorAction Stop
                Write-ColoredHost "Successfully uninstalled module '$moduleName' from CurrentUser scope." -ForegroundColor $ColorSuccess
            }
            catch {
                Write-ColoredHost "Failed to uninstall module '$moduleName' from CurrentUser scope. Error: $($_.Exception.Message)" -ForegroundColor $ColorWarning
                Write-ColoredHost "You may need to remove it manually or check permissions. Ensure no PowerShell sessions are currently using the module." -ForegroundColor $ColorWarning
            }
        } else {
            Write-ColoredHost "Module '$moduleName' is not installed for CurrentUser scope. Skipping uninstallation for this scope." -ForegroundColor $ColorDebug
        }
    }
    catch {
        # This catch block is for errors from Get-InstalledModule itself
        Write-ColoredHost "Could not check or uninstall module '$moduleName' for CurrentUser scope. Error: $($_.Exception.Message)" -ForegroundColor $ColorWarning
        Write-ColoredHost "This might happen if PowerShellGet module is missing or not functioning correctly for the current user." -ForegroundColor $ColorWarning
    }
    Write-Host "" 
}
Write-Host ""
 #>

Write-ColoredHost "[Cleanup This Uninstallation Script's Log (Optional)]" -ForegroundColor $ColorSection
Write-ColoredHost "The log for this uninstallation session is at: $logFilePath" -ForegroundColor $ColorInfo
Write-ColoredHost "This script does not automatically delete its own log file upon completion." -ForegroundColor $ColorInfo

$installTimeLogFile = "C:\Temp\OutlookSignatureLog.txt" 
Write-ColoredHost "If you wish to clean up the main log file at '$installTimeLogFile', do so manually or via a separate process." -ForegroundColor $ColorInfo
Write-ColoredHost "This script will not delete it automatically to preserve records." -ForegroundColor $ColorInfo
Write-Host ""


Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Write-ColoredHost "SCRIPT FINISHED: Outlook Signature Manager Uninstallation" -ForegroundColor $ColorSection
Write-ColoredHost "-----------------------------------------------------------------" -ForegroundColor $ColorSection
Stop-Transcript
