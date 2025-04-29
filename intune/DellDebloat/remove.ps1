

# Stripped out the Dell sections from the following debloat script 
# https://andrewstaylor.com/2022/08/09/removing-bloatware-from-windows-10-11-via-script/

Write-Output " 
_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_                                                     
    ____           __    __           ____           __      __                  __        
   / __ \  ___    / /   / /          / __ \  ___    / /_    / /  ____   ____ _  / /_       
  / / / / / _ \  / /   / /  ______  / / / / / _ \  / __ \  / /  / __ \ / __ `/ / __/       
 / /_/ / /  __/ / /   / /  /_____/ / /_/ / /  __/ / /_/ / / /  / /_/ // /_/ / / /_         
/_____/  \___/ /_/   /_/          /_____/  \___/ /_.___/ /_/   \____/ \__,_/  \__/         
                                                                                                                                                     
_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_
                                                                                                      "



    $UninstallPrograms = @(
        "Dell Optimizer"
        "Dell Power Manager"
        "DellOptimizerUI"
        "Dell SupportAssist OS Recovery"
        "Dell SupportAssist"
        "Dell Optimizer Service"
        "Dell Optimizer Core"
        "DellInc.PartnerPromo"
        "DellInc.DellOptimizer"
        "DellInc.DellCommandUpdate"
        "DellInc.DellPowerManager"
        "DellInc.DellDigitalDelivery"
        "DellInc.DellSupportAssistforPCs"
        "DellInc.PartnerPromo"
        "Dell Command | Update"
        "Dell Command | Update for Windows Universal"
        "Dell Command | Update for Windows 10"
        "Dell Command | Power Manager"
        "Dell Digital Delivery Service"
        "Dell Digital Delivery"
        "Dell Peripheral Manager"
        "Dell Power Manager Service"
        "Dell SupportAssist Remediation"
        "SupportAssist Recovery Assistant"
        "Dell SupportAssist OS Recovery Plugin for Dell Update"
        "Dell SupportAssistAgent"
        "Dell Update - SupportAssist Update Plugin"
        "Dell Core Services"
        "Dell Pair"
        "Dell Display Manager 2.0"
        "Dell Display Manager 2.1"
        "Dell Display Manager 2.2"
        "Dell SupportAssist Remediation"
        "Dell Update - SupportAssist Update Plugin"
        "DellInc.PartnerPromo"
    )



    $UninstallPrograms = $UninstallPrograms | Where-Object { $appstoignore -notcontains $_ }


    foreach ($app in $UninstallPrograms) {

        if (Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app -ErrorAction SilentlyContinue) {
            Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $app | Remove-AppxProvisionedPackage -Online
            write-output "Removed provisioned package for $app."
        }
        else {
            write-output "Provisioned package for $app not found."
        }

        if (Get-AppxPackage -allusers -Name $app -ErrorAction SilentlyContinue) {
            Get-AppxPackage -allusers -Name $app | Remove-AppxPackage -AllUsers
            write-output "Removed $app."
        }
        else {
            write-output "$app not found."
        }

        UninstallAppFull -appName $app



    }

    foreach ($program in $UninstallPrograms) {
        write-output "Removing $program if it exists via CIM..."
        Get-CimInstance -Query "SELECT * FROM Win32_Product WHERE Name = '$program'" | Invoke-CimMethod -MethodName Uninstall -ErrorAction SilentlyContinue
    }


    $dellSA = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Dell*Optimizer*Core" } | Select-Object -Property UninstallString

    ForEach ($sa in $dellSA) {
        If ($sa.UninstallString) {
            try {
                write-output "Attempting silent uninstall of Dell Optimizer Core using: $($sa.UninstallString)"
                $procArgs = ($sa.UninstallString -replace '"', '') + " -silent" # Example, adjust silent flag as needed
                Start-Process -FilePath ($procArgs.Split(' ')[0]) -ArgumentList ($procArgs.Split(' ', 2)[1]) -Wait -NoNewWindow -ErrorAction Stop
                write-output "Dell Optimizer Core uninstall command executed."
            }
            catch {
                Write-Warning "Failed to uninstall Dell Optimizer Core using string: $($sa.UninstallString). Error: $($_.Exception.Message)"
            }
        }
    }


    ##Dell Dell SupportAssist Remediation
    # Note: QuietUninstallString is often more reliable for silent uninstalls if available
    $dellSA = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Dell SupportAssist Remediation" } | Select-Object -Property QuietUninstallString, UninstallString

    ForEach ($sa in $dellSA) {
        $uninstallCmd = $sa.QuietUninstallString # Prefer QuietUninstallString
        if (-not $uninstallCmd) { $uninstallCmd = $sa.UninstallString } # Fallback to UninstallString

        If ($uninstallCmd) {
            try {
                 write-output "Attempting silent uninstall of Dell SupportAssist Remediation using: $uninstallCmd"
                 # Assuming QuietUninstallString is already silent or UninstallString needs silent flags
                 if ($uninstallCmd -match "msiexec") {
                     $args = ($uninstallCmd -replace "/I", "/X ") -replace "msiexec.exe ",""
                     $args += " /qn /norestart"
                     Start-Process msiexec.exe -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
                 } else {
                    # Heuristic: add common silent flags if not MSIEXEC
                    $proc = ($uninstallCmd -replace '"','').Split(' ')[0]
                    $args = ($uninstallCmd -replace '"','').Split(' ',2)[1]
                    if ($args -notmatch '(/s|/S|/q|/Q|/quiet|/silent)') {$args += " /S"} # Common silent flag
                     Start-Process -FilePath $proc -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
                 }
                write-output "Dell SupportAssist Remediation uninstall command executed."
            }
            catch {
                Write-Warning "Failed to uninstall Dell Support Assist Remediation using string: $uninstallCmd. Error: $($_.Exception.Message)"
            }
        }
    }

    ##Dell Dell SupportAssist OS Recovery Plugin for Dell Update
    $dellSA = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Dell SupportAssist OS Recovery Plugin for Dell Update" } | Select-Object -Property QuietUninstallString, UninstallString

    ForEach ($sa in $dellSA) {
       $uninstallCmd = $sa.QuietUninstallString # Prefer QuietUninstallString
        if (-not $uninstallCmd) { $uninstallCmd = $sa.UninstallString } # Fallback to UninstallString

        If ($uninstallCmd) {
            try {
                 write-output "Attempting silent uninstall of Dell SupportAssist OS Recovery Plugin using: $uninstallCmd"
                 if ($uninstallCmd -match "msiexec") {
                     $args = ($uninstallCmd -replace "/I", "/X ") -replace "msiexec.exe ",""
                     $args += " /qn /norestart"
                     Start-Process msiexec.exe -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
                 } else {
                     $proc = ($uninstallCmd -replace '"','').Split(' ')[0]
                     $args = ($uninstallCmd -replace '"','').Split(' ',2)[1]
                     if ($args -notmatch '(/s|/S|/q|/Q|/quiet|/silent)') {$args += " /S"}
                     Start-Process -FilePath $proc -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
                 }
                write-output "Dell SupportAssist OS Recovery Plugin uninstall command executed."
            }
            catch {
                Write-Warning "Failed to uninstall Dell SupportAssist OS Recovery Plugin using string: $uninstallCmd. Error: $($_.Exception.Message)"
            }
        }
    }

    ##Dell Display Manager
    $dellSA = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall -ErrorAction SilentlyContinue | Get-ItemProperty -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "Dell*Display*Manager*" } | Select-Object -Property UninstallString

    ForEach ($sa in $dellSA) {
        If ($sa.UninstallString) {
            try {
                $uninstallCmd = $sa.UninstallString
                write-output "Attempting silent uninstall of Dell Display Manager using: $uninstallCmd /S"
                $proc = ($uninstallCmd -replace '"','').Split(' ')[0]
                $args = ($uninstallCmd -replace '"','').Split(' ',2)[1]
                $args += " /S" # Explicitly add /S for Dell Display Manager
                Start-Process -FilePath $proc -ArgumentList $args -Wait -NoNewWindow -ErrorAction Stop
                write-output "Dell Display Manager uninstall command executed."
            }
            catch {
                Write-Warning "Failed to uninstall Dell Display Manager using string: $($sa.UninstallString). Error: $($_.Exception.Message)"
            }
        }
    }

    ##Dell Peripheral Manager
    $dpmPath = "C:\Program Files\Dell\Dell Peripheral Manager\Uninstall.exe"
    if (Test-Path $dpmPath) {
        try {
            write-output "Attempting silent uninstall of Dell Peripheral Manager"
            Start-Process -FilePath $dpmPath -ArgumentList "/S" -Wait -NoNewWindow -ErrorAction Stop
             write-output "Dell Peripheral Manager uninstall command executed."
        }
        catch {
            Write-Warning "Failed to uninstall Dell Peripheral Manager using $dpmPath /S. Error: $($_.Exception.Message)"
        }
    } else {
        write-output "Dell Peripheral Manager uninstaller not found at $dpmPath"
    }


    ##Dell Pair
    $dpPath = "C:\Program Files\Dell\Dell Pair\Uninstall.exe"
     if (Test-Path $dpPath) {
        try {
            write-output "Attempting silent uninstall of Dell Pair"
            Start-Process -FilePath $dpPath -ArgumentList "/S" -Wait -NoNewWindow -ErrorAction Stop
            write-output "Dell Pair uninstall command executed."
        }
        catch {
            Write-Warning "Failed to uninstall Dell Pair using $dpPath /S. Error: $($_.Exception.Message)"
        }
     } else {
         write-output "Dell Pair uninstaller not found at $dpPath"
     }

