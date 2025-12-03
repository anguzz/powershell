$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sourcePath = Join-Path $scriptPath "Files"

# Change these variables based on your EXE/MSI install
$installerFolderName = "FolderNameHere"
$installRoot        = "C:\Installers"
$destinationPath    = Join-Path $installRoot $installerFolderName

# Ensure base install folder exists for logs & installers
if (-Not (Test-Path -Path $installRoot)) {
    New-Item -Path $installRoot -ItemType Directory -Force | Out-Null
}

# --- Transcript logging for ALL script output ---
$transcriptPath    = Join-Path $installRoot "log.txt"
$transcriptStarted = $false

try {
    Start-Transcript -Path $transcriptPath -Append
    $transcriptStarted = $true
    Write-Output "Started transcript logging to $transcriptPath"
}
catch {
    Write-Output "Failed to start transcript at $transcriptPath. Error: $_"
}

try {
    # Ensure destination folder exists
    if (-Not (Test-Path -Path $destinationPath)) {
        New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
        Write-Output "Created destination folder: $destinationPath"
    }

    Write-Output "Script starting at $(Get-Date)"
    Write-Output "Source path: $sourcePath"
    Write-Output "Destination path: $destinationPath"

    # Copy installer files
    if (Test-Path -Path $sourcePath) {
        Write-Output "Copying files from $sourcePath to $destinationPath"
        Copy-Item -Path (Join-Path $sourcePath '*') -Destination $destinationPath -Force
    }
    else {
        Write-Output "Source path $sourcePath does not exist. Exiting."
        return
    }

    Start-Sleep -Seconds 5

    # --- MSI-specific setup & logging ---
    $fileName = "example.msi"  # add the MSI file name here
    $filePath = Join-Path $destinationPath $fileName

    # MSI log will be placed next to the MSI
    $msiBaseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $msiLogName  = "${msiBaseName}_install.log"
    $msiLogPath  = Join-Path $destinationPath $msiLogName

    # Check for MSI file and install if present
    if (Test-Path -Path $filePath) {
        Write-Output "Found MSI at $filePath"
        Write-Output "Installing MSI. Detailed MSI log: $msiLogPath"

        $arguments = "/i `"$filePath`" /quiet /norestart /L*v `"$msiLogPath`""

        $process = Start-Process -FilePath "msiexec.exe" `
                                  -ArgumentList $arguments `
                                  -Wait `
                                  -PassThru

        Write-Output "msiexec exited with code $($process.ExitCode)"

        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Output "MSI application installed successfully."
        }
        else {
            Write-Output "MSI install encountered an issue. Exit code: $($process.ExitCode)"
        }
    }
    else {
        Write-Output "The MSI file $filePath does not exist."
    }

    Write-Output "Script completed at $(Get-Date)"
}
finally {
    if ($transcriptStarted) {
        try {
            Stop-Transcript | Out-Null
        }
        catch {
            Write-Output "Failed to stop transcript cleanly: $_"
        }
    }
}
