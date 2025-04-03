
Write-Output "`n`n`n`n          :::     :::    ::: ::::::::::: ::::::::  :::::::::   :::::::: ::::::::::: 
       :+: :+:   :+:    :+:     :+:    :+:    :+: :+:    :+: :+:    :+:    :+:      
     +:+   +:+  +:+    +:+     +:+    +:+    +:+ +:+    +:+ +:+    +:+    +:+       
   +#++:++#++: +#+    +:+     +#+    +#+    +:+ +#++:++#+  +#+    +:+    +#+        
  +#+     +#+ +#+    +#+     +#+    +#+    +#+ +#+    +#+ +#+    +#+    +#+         
 #+#     #+# #+#    #+#     #+#    #+#    #+# #+#    #+# #+#    #+#    #+#          
###     ###  ########      ###     ########  #########   ########     ###           `n`n`n`n"

do {

    Write-Output "`n 1. Enroll device in Autopilot (admin)"
    Write-Output "`n 2. Generate hash and store on USB "
    Write-Output "`n 3. Exit shell"

    $userChoice = Read-Host "  `n Select an option:(1-3) `n`n"

    switch ($userChoice) {
        "1" {
            # from https://learn.microsoft.com/en-us/autopilot/add-devices 
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned

            Install-Script -Name Get-WindowsAutopilotInfo -Force

            Get-WindowsAutopilotInfo -Online

            $deviceSerial=  Get-WmiObject -Class Win32_BIOS | Select-Object -Property SerialNumber   

            Write-Output "Device enrollment initiated. Please check intune to verify device serial was added" 
        }
        "2"{
        Install-PackageProvider -Name NuGet -Confirm:$false -Force
        Install-Script -Name Get-WindowsAutoPilotInfo -Confirm:$false -Force
        Set-ExecutionPolicy Bypass -Scope Process -Force
        $hashFile = "C:\hash.csv"
        
        Write-Host "Generating Autopilot Hardware Hash to $hashFile..."
        Get-WindowsAutoPilotInfo.ps1 -OutputFile $hashFile
        
        $drives = Get-CimInstance Win32_Volume | Where-Object { $_.DriveType -in 2,3 -and $_.DriveLetter }
        
        if ($drives) {
            Write-Host "Available drives:"
            $drives | Select-Object DriveLetter, @{N='Size(GB)';E={[math]::Round($_.Capacity / 1GB, 1)}} | Format-Table -AutoSize
        
            $copyChoice = Read-Host "Copy '$hashFile' to one drive? (Y/N)"
            if ($copyChoice -match '^[Yy]$') {
                $letter = Read-Host "Enter the target drive letter (e.g., D)"
                if ($letter -match '^[A-Za-z]$') {
                    $targetDrive = ($letter.Trim() + ":").ToUpper()
                    if ($drives.DriveLetter -contains $targetDrive) {
                        $destination = Join-Path -Path $targetDrive -ChildPath "hash.csv"
                        Copy-Item -Path $hashFile -Destination $destination -Force
                        Write-Host "Copied '$hashFile' to '$destination'" -ForegroundColor Green
                    } else {
                        Write-Warning "Drive letter '$letter' not found in the available list."
                    }
                } else {
                    Write-Warning "Invalid input: '$letter'. Please enter a single letter."
                }
            }
        } else {
            Write-Warning "No suitable drives found to copy the hash file to."
        }
    }
        "3" {
            Write-Output "Exiting program."
            exit
        }
        default {
            Write-Output "Invalid option selected. Please select a valid option."
        }
    }
}
while ($userChoice -ne '3')
