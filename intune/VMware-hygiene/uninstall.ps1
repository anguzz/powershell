#log file path 
$LogFilePath = "C:\Temp\Horizon_Uninstall_Log.txt"

$ApplicationsToRemove = @(
    "VMware Horizon Client",
    "VMware Horizon Media Engine*",
    "VMware Horizon Media Redirection for Microsoft Teams*"
)

$ProcessesToStop = @(
    "vmware-view",
    "vmware-remotemks",
    "vmware-view-usbd",
    "vmware-horizon-media-provider"
)


function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $TimeStamp = "[{0:MM/dd/yyyy HH:mm:ss}]" -f (Get-Date)
    $LogMessage = "$TimeStamp $Message"

    Write-Host $LogMessage

    try {
        $LogDirectory = Split-Path -Path $LogFilePath -Parent
        if (-not (Test-Path -Path $LogDirectory -PathType Container)) {
            Write-Host "DEBUG: Log directory '$LogDirectory' not found. Creating..."
            New-Item -ItemType Directory -Path $LogDirectory -Force -ErrorAction Stop | Out-Null
        }

        Add-Content -Path $LogFilePath -Value $LogMessage -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write log entry to '$LogFilePath'. Error: $($_.Exception.Message)"
    }
}

#Process Termination
Write-Log "INFO: Starting script execution. Attempting to stop Horizon Client related processes..."
$processesStopped = $false
foreach ($procName in $ProcessesToStop) {
    $processes = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($processes) {
        Write-Log "INFO: Found running process: $($procName). Attempting to stop..."
        Stop-Process -Name $procName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        $verifyProcess = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($verifyProcess) {
            Write-Log "WARN: Process '$($procName)' may not have stopped completely."
        } else {
            Write-Log "INFO: Process '$($procName)' stopped successfully."
            $processesStopped = $true
        }
    } else {
        Write-Log "INFO: Process '$($procName)' not found running."
    }
}

if ($processesStopped) {
    Write-Log "INFO: Pausing for a few seconds after stopping processes before uninstall."
    Start-Sleep -Seconds 10
}
Write-Log "INFO: Process termination phase complete."



# uninstall Logic
Write-Log "INFO: Starting application uninstall phase."

$uninstallRegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

function Uninstall-Application {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppNamePattern
    )

    Write-Log "INFO: Searching for application matching pattern: '$AppNamePattern'"
    $uninstallInfo = $null
    $foundApp = $false

    foreach ($regPath in $uninstallRegPaths) {
        if (Test-Path $regPath) {
             Write-Log "DEBUG: Checking registry path: $regPath"
             try {
                 $uninstallKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | ForEach-Object { Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue }

                 $matchingApps = $uninstallKeys | Where-Object {
                     $null -ne $_.PSObject.Properties['DisplayName'] -and
                     $_.DisplayName -like $AppNamePattern -and
                     $null -ne $_.PSObject.Properties['UninstallString'] -and $_.UninstallString -ne '' -and
                     ($null -eq $_.PSObject.Properties['SystemComponent'] -or $_.SystemComponent -ne 1)
                 }

                 if ($matchingApps) {
                     $uninstallInfo = $matchingApps | Select-Object -First 1
                     Write-Log "INFO: Found uninstall information for '$($uninstallInfo.DisplayName)' in path '$regPath'."
                     $foundApp = $true
                     break
                 }
             } catch {
                 Write-Log "WARN: Error accessing registry path $regPath. $_"
             }
        } else {
             Write-Log "DEBUG: Registry path not found: $regPath"
        }
    }

    if (-not $foundApp) {
        Write-Log "INFO: No uninstall information found for pattern '$AppNamePattern'. It might already be uninstalled or name is incorrect."
        return
    }

    $uninstallCommand = $uninstallInfo.UninstallString
    $displayName = $uninstallInfo.DisplayName
    Write-Log "INFO: Preparing to uninstall '$displayName'. Original Uninstall string: '$uninstallCommand'"

    $commandPath = ""
    $arguments = ""
    $productCode = $null

    try {
        if ($uninstallCommand -match 'VMware-Horizon-Client.*\.exe') {
            Write-Log "DEBUG: Detected VMware Horizon Client EXE uninstaller."
            if ($uninstallCommand -match '^"([^"]+)"') {
                 $commandPath = $Matches[1]
            } elseif ($uninstallCommand -match '^([^ ]+\.exe)') {
                 $commandPath = $Matches[1]
            } else {
                 Write-Log "WARN: Could not reliably parse Horizon Client EXE path from '$uninstallCommand'. Assuming first part."
                 $commandPath = ($uninstallCommand -split ' ')[0]
            }

            $arguments = "/silent /uninstall /norestart"
            Write-Log "INFO: Using specific arguments for Horizon Client EXE: '$arguments'"

        } elseif ($uninstallCommand -match 'msiexec' -or $uninstallCommand -match 'MsiExec') {
            Write-Log "DEBUG: Detected MSIExec command."
            $commandPath = "msiexec.exe"
            $baseArgs = "" 

            if ($uninstallCommand -match '(\{([A-Fa-f0-9]{8}-([A-Fa-f0-9]{4}-){3}[A-Fa-f0-9]{12})\})') {
                $productCode = $Matches[1] 
                Write-Log "DEBUG: Extracted ProductCode GUID: $productCode"
                $baseArgs = "/X $productCode"
            } elseif ($uninstallCommand -match '/[xX]\s+("?([^"]+\.msi)"?|\S+\.msi)') {
                 $msiPath = $Matches[2] 
                 Write-Log "DEBUG: Extracted MSI Path: $msiPath"
                 if ($msiPath -match '\s' -and -not ($msiPath.StartsWith('"') -and $msiPath.EndsWith('"'))) {
                     $msiPath = "`"$msiPath`""
                 }
                 $baseArgs = "/X $msiPath"
            } else {
                if ($uninstallInfo.PSChildName -match '^\{([A-Fa-f0-9]{8}-([A-Fa-f0-9]{4}-){3}[A-Fa-f0-9]{12})\}$') {
                    $productCode = $uninstallInfo.PSChildName
                     Write-Log "DEBUG: Using ProductCode from Registry Key Name: $productCode"
                    $baseArgs = "/X $productCode"
                } else {
                    Write-Log "WARN: Could not reliably determine ProductCode or MSI path from '$uninstallCommand' or registry key. Cannot guarantee '/REBOOT=ReallySuppress'. Attempting basic MSI uninstall."
                    $arguments = $uninstallCommand -replace '(?i)msiexec.exe\s*',''
                    if ($arguments -notmatch '/[xX]') { $arguments = "/X " + $arguments }
                    if ($arguments -notmatch '/qn') { $arguments = $arguments -replace '/[qQ][bBnN!-]*/','' ; $arguments += " /qn"}
                    if ($arguments -notmatch '/norestart') { $arguments += " /norestart"} # Add norestart
                    $arguments = $arguments -replace '/promptrestart|/forcerestart', '' # Remove conflicting flags
                    $arguments = $arguments.Trim() -replace '\s{2,}', ' '
                }
            }

            if ($baseArgs) {
                 $arguments = "$baseArgs /qn /norestart /REBOOT=ReallySuppress"
                 Write-Log "INFO: Using robust arguments for MSI: '$arguments'"
            } elseif (-not $arguments) {
                 Write-Log "ERROR: Failed to construct valid MSI arguments for '$displayName'. Skipping."
                 return
            }


        } elseif ($uninstallCommand -match '\.exe') {
             Write-Log "DEBUG: Detected generic .EXE command."
             if ($uninstallCommand -match '^"([^"]+)"(.*)' -or $uninstallCommand -match '^([^ ]+)(.*)') {
                 $commandPath = $Matches[1]
                 $arguments = $Matches[2].Trim()
                 if ($arguments -notmatch '(/S|/s|/silent|SILENT|/quiet|/QUIET|/qn|/QN)') {
                     Write-Log "DEBUG: No common silent switch detected in generic EXE arguments. Adding '/S'."
                     $arguments += " /S"
                 }
                
                 $arguments = $arguments.Trim() -replace '\s{2,}', ' '
             } else {
                 Write-Log "WARN: Could not accurately parse generic EXE command line: $uninstallCommand. Attempting raw execution."
                 $commandPath = $uninstallCommand; $arguments = "" 
             }

        } else {
             Write-Log "WARN: Unrecognized uninstall string format: '$uninstallCommand'. Attempting raw execution."
             if ($uninstallCommand -match '^"([^"]+)"') { $commandPath = $Matches[1] }
             else { $commandPath = ($uninstallCommand -split ' ')[0] }
             $arguments = "" # No arguments for raw execution attempt
        }

        if (-not $commandPath) {
             Write-Log "ERROR: Could not determine command path for '$displayName'. Skipping."
             return
        }
        if (-not (Test-Path -Path $commandPath -ErrorAction SilentlyContinue)) {
             Write-Log "ERROR: Command path '$commandPath' not found for '$displayName'. Skipping."
             return
        }

        Write-Log "INFO: Executing: '$commandPath' with arguments: '$arguments'"
        $process = Start-Process -FilePath $commandPath -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop

        $exitCode = $process.ExitCode
        if ($exitCode -in @(0, 3010)) { # 0 = Success, 3010 = Success, soft Reboot Required
             $status = if ($exitCode -eq 3010) { "(Reboot Required but Suppressed by Script where possible)" } else { "(Success)" } 
             Write-Log "INFO: Uninstall command for '$displayName' finished. Exit Code: $exitCode $status"

        } else {
             Write-Log "WARN: Uninstall command for '$displayName' finished with Exit Code: $exitCode. This might indicate an issue or specific condition (e.g., 1603=Failure, 1605=Not Installed, 1641=Reboot Forced by Installer)."
        }

    } catch {
        Write-Log "ERROR: Failed to execute uninstall command for '$displayName'. Error: $($_.Exception.Message)"
    }
} 


Write-Log "INFO: Starting VMware Horizon Client component uninstallation script."

foreach ($appPattern in $ApplicationsToRemove) {
    Uninstall-Application -AppNamePattern $appPattern
    Write-Log "INFO: Pausing briefly before next application."
    Start-Sleep -Seconds 5
}


Write-Log "INFO: Script execution finished."
exit 0
