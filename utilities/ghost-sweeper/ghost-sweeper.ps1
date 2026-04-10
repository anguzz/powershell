<#
.SYNOPSIS
  spy-sweeper.ps1 - Professional Privacy Auditor & Stealth Tracker Finder.
.DESCRIPTION
  Updated for 2026 with deep-scan signatures for invisible monitoring agents.
#>

Write-Output "
  ________.__                    __   _________                                          
 /  _____/|  |__   ____  _______/  |_/   _____/_  _  __ ____   ____ ______   ___________ 
/   \  ___|  |  \ /  _ \/  ___/\   __\_____  \\ \/ \/ // __ \_/ __ \\____ \_/ __ \_  __ \
\    \_\  \   Y  (  <_> )___ \  |  | /        \\     /\  ___/\  ___/|  |_> >  ___/|  | \/
 \______  /___|  /\____/____  > |__|/_______  / \/\_/  \___  >\___  >   __/ \___  >__|   
        \/     \/           \/              \/             \/     \/|__|        \/        "

# ---------- Deep Scan Signatures (2026 Update) ----------
$Signatures = @{
    "ActivTrak (Stealth)" = @{
        Processes    = @("scthost", "scthostp", "activtrakagent")
        Paths        = @("C:\Windows\SysWOW64\scthost.exe", "C:\Windows\System32\scthost.exe", "$env:PROGRAMDATA\ActivTrak")
        Services     = @("ActivTrakAgent")
    }
    "Teramind (Silent)" = @{
        Processes    = @("tmagent", "tm-service", "teramind-agent")
        Paths        = @("C:\ProgramData\{4CEC2908-5CE4-48F0-A717-8FC833D8017A}", "C:\Teramind")
        Services     = @("TeramindAgent")
    }
    "Monitask (Invisible)" = @{
        Processes    = @("deskcap", "monitask")
        Paths        = @("C:\Users\Public\Monitask", "$env:LOCALAPPDATA\Monitask")
    }
    "SentryPC (Cloaked)" = @{
        Processes    = @("spcagent", "spcclient", "sentrypc")
        Paths        = @("C:\Windows\syswow64\spc", "C:\Program Files\SentryPC")
    }
    "Veriato / InterGuard" = @{
        Processes    = @("dgagent", "cltutil", "veriato")
        Paths        = @("C:\Windows\system32\dgagent", "C:\Program Files\Veriato")
        Services     = @("VeriatoService")
    }
    "Insightful (Stealth Mode)" = @{
        Processes    = @("insightfulagent", "insightful")
        Paths        = @("$env:PROGRAMDATA\Insightful", "C:\Program Files\Insightful")
    }
    "CurrentWare (Stealth)" = @{
        Processes    = @("cwClient", "brClient")
        Services     = @("cwClientService")
    }
}

# ---------- Helper Functions ----------
function Expand-EnvPath($p) { return [Environment]::ExpandEnvironmentVariables($p) }

function Match-Pattern($inputString, $patterns) {
    if (-not $inputString) { return $false }
    foreach ($pat in $patterns) {
        if ($inputString -imatch [regex]::Escape($pat)) { return $true }
    }
    return $false
}

# ---------- Scan Execution ----------
$report = [System.Collections.ArrayList]::new()
$now = Get-Date
Write-Host "`n[i] Starting GhostSweeper deep scan..." -ForegroundColor Cyan

# Gather Snapshots
$uninstalls = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*", 
                               "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", 
                               "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue
$procs = Get-Process -ErrorAction SilentlyContinue
$svcs = Get-Service -ErrorAction SilentlyContinue

function New-Hit($prod, $type, $ev, $det) {
    $report.Add([PSCustomObject]@{
        Product = $prod; Type = $type; Evidence = $ev; Details = $det; Time = $now.ToString("T")
    }) | Out-Null
}

# 1. Signature Check
foreach ($key in $Signatures.Keys) {
    $s = $Signatures[$key]
    
    # Process Scan
    if ($s.Processes) {
        $procs | Where-Object { Match-Pattern $_.Name $s.Processes } | ForEach-Object {
            New-Hit $key "Process" $_.Name ("Stealth Process Detected: $($_.Name)")
        }
    }
    # Path Scan
    if ($s.Paths) {
        foreach ($p in $s.Paths) {
            if (Test-Path (Expand-EnvPath $p)) { New-Hit $key "File/Path" $p "Stealth directory found." }
        }
    }
    # Service Scan
    if ($s.Services) {
        $svcs | Where-Object { Match-Pattern $_.Name $s.Services } | ForEach-Object {
            New-Hit $key "Service" $_.Name "Background service is active."
        }
    }
}

# 2. Registry Persistence Scan (The "Run" Keys)
$runKeys = @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run")
foreach ($rk in $runKeys) {
    $vals = Get-ItemProperty $rk -ErrorAction SilentlyContinue
    if ($vals) {
        $vals.PSObject.Properties | Where-Object { $_.Name -notmatch "PSPath|PSParentPath" } | ForEach-Object {
            if ($_.Value -imatch "scthost|deskcap|dgagent|spcagent|tmagent") {
                New-Hit "Generic Stealth" "Startup Entry" $_.Name "Suspicious persistence: $($_.Value)"
            }
        }
    }
}

# ---------- Reporting ----------
if ($report.Count -gt 0) {
    Write-Host "`n[!] CRITICAL: found $($report.Count) stealth tracking indicators." -ForegroundColor Yellow
    $report | Sort-Object Product | Format-Table Product, Type, Evidence, Details -AutoSize
} else {
    Write-Host "`n[+] System looks clean. No stealth agents found." -ForegroundColor Green
}

Write-Host "`n--- Scan Complete ---" -ForegroundColor Cyan