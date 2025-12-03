$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sourcePath = Join-Path $scriptPath "Files"

# -------------------------------
# Change these per EXE/package
# -------------------------------
$installerFolderName = "FolderNameHere"      # Folder name under C:\Installers
$installRoot         = "C:\Installers"       # Root for installers + transcript
$destinationPath     = Join-Path $installRoot $installerFolderName

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

    # -------------------------------
    # EXE-specific setup & logging
    # -------------------------------
    $fileName = "example.exe"  # add EXE file name here
    $filePath = Join-Path $destinationPath $fileName

    # EXE log will be placed next to the EXE
    $exeBaseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    $exeLogName  = "${exeBaseName}_install.log"
    $exeLogPath  = Join-Path $destinationPath $exeLogName

    # NOTE:
    # Many EXE installers support a log flag like:
    #   /log "path", /L*v "path", or /LOG="path"
    # Update this line to match the EXE's supported flags (/?, /help, etc).
    #
    # Example (adjust as needed):
    #   $installCommand = "/install /quiet /norestart /log `"$exeLogPath`""
    #
    # Default generic command without explicit EXE log:
    $installCommand = "/install /quiet /norestart"

    if (Test-Path -Path $filePath) {
        Write-Output "Found EXE at $filePath"
        Write-Output "EXE log path (if supported by installer): $exeLogPath"
        Write-Output "Running install command: $installCommand"

        # Run EXE
        $process = Start-Process -FilePath $filePath `
                                 -ArgumentList $installCommand `
                                 -Wait `
                                 -PassThru

        Write-Output "Installer exited with code $($process.ExitCode)"

        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
            Write-Output "EXE application installed successfully."
        }
        else {
            Write-Output "EXE install encountered an issue. Exit code: $($process.ExitCode)"
        }
    }
    else {
        Write-Output "The EXE file $filePath does not exist."
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
