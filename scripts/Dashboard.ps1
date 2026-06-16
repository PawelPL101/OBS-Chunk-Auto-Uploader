# =============================================================================
# OBS Chunk Auto-Uploader (Version 1.0.0)
# Copyright (c) 2026 PawelPL101
# Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
# NOT distribute modified versions. See LICENSE.txt for full terms.
# =============================================================================

# =============================================================================
# Dashboard.ps1
# Live dashboard for the OBS Chunk Uploader.
# Uses Clear-Host + redraw each cycle -> works in EVERY terminal (Windows
# Terminal, conhost, etc.) with zero spam. Updates every 2s.
# Close window to exit. (Closing this does NOT stop the uploader.)
# Developed by PawelPL101
# =============================================================================

# Load user settings from config.txt
. (Join-Path $PSScriptRoot "Load-Config.ps1")
$cfg = Get-OBSConfig

# The app's root folder is the parent of this scripts/ folder.
$AppRoot      = Split-Path $PSScriptRoot -Parent
$DataDir      = Join-Path $AppRoot "data"

$WatchFolder  = $cfg["WatchFolder"]
$LogFile      = Join-Path $WatchFolder "upload-log.txt"
$StatsFile    = Join-Path $DataDir "lifetime-stats.txt"
$ProgressFile = Join-Path $DataDir "progress.txt"
$Adapter      = $cfg["NetworkAdapter"]
$FileExt      = $cfg["FileExtension"]

$Host.UI.RawUI.WindowTitle = "OBS Uploader - Live Dashboard"
[Console]::CursorVisible = $false

$SessionStart = Get-Date

function Get-LifetimeTotal {
    if (Test-Path $StatsFile) {
        try { return [double](Get-Content $StatsFile -Raw).Trim() } catch { return 0.0 }
    }
    return 0.0
}

function Get-Progress {
    $result = @{ Active = $false; Speed = "-"; Percent = "-"; Eta = "-" }
    if (-not (Test-Path $ProgressFile)) { return $result }
    try {
        $raw = (Get-Content $ProgressFile -Raw -ErrorAction Stop).Trim()
    } catch { return $result }

    if ($raw -like "UPLOADING|*") {
        $parts = $raw -split "\|", 3
        $line = if ($parts.Count -ge 3) { $parts[2] } else { "" }
        $result.Active = $true
        if ($line -match "(\d+)%") { $result.Percent = "$($Matches[1])%" }
        if ($line -match "([\d\.]+\s*[KMG]i?B/s)") { $result.Speed = $Matches[1] }
        if ($line -match "ETA\s+([\dhms]+)") { $result.Eta = $Matches[1] }
        if ($line -match "starting") { $result.Speed = "starting..." }
    }
    return $result
}

while ($true) {
    $completed = 0; $deleted = 0; $errors = 0; $sessionGB = 0; $lastLine = ""; $status = "Starting..."; $statusColor = "Yellow"

    if (Test-Path $LogFile) {
        $lines = Get-Content $LogFile -Tail 300 -ErrorAction SilentlyContinue

        $completed = @($lines | Where-Object { $_ -match "PIPELINE COMPLETE" }).Count
        $deleted   = @($lines | Where-Object { $_ -match "LOCAL DELETE" }).Count

        $errors = 0
        foreach ($l in $lines) {
            if ($l -match "FAILED|ABORTED") {
                if ($l -match "^\[(.+?)\]") {
                    try {
                        $ts = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm:ss", $null)
                        if ($ts -ge $SessionStart) { $errors++ }
                    } catch { }
                }
            }
        }

        # Sum sizes of SUCCESSFULLY completed uploads only (not failed attempts).
        # We capture the size logged at UPLOAD START but only count it if that
        # same file later reached PIPELINE COMPLETE.
        $sessionGB = 0
        $completedFiles = @{}
        foreach ($l in $lines) {
            if ($l -match "PIPELINE COMPLETE: (.+)$") {
                $completedFiles[$Matches[1].Trim()] = $true
            }
        }
        foreach ($l in $lines) {
            if ($l -match "UPLOAD START: (.+) \(([\d\.]+) GB\)") {
                $fn = $Matches[1].Trim()
                $gb = [double]$Matches[2]
                if ($completedFiles.ContainsKey($fn)) {
                    $sessionGB += $gb
                }
            }
        }
        $sessionGB = [math]::Round($sessionGB, 2)

        $lastLine = ($lines | Where-Object { $_ -notmatch '-{10,}' } | Select-Object -Last 1)

        if ($lastLine -match "UPLOAD START|UPLOAD COMPLETE") {
            $status = "Uploading chunk to cloud..."; $statusColor = "Yellow"
        } elseif ($lastLine -match "VERIFY") {
            $status = "Verifying checksum..."; $statusColor = "Yellow"
        } elseif ($lastLine -match "LOCAL DELETE|PIPELINE COMPLETE") {
            $status = "Finishing up chunk..."; $statusColor = "Cyan"
        } elseif ($lastLine -match "IDLE|Polling|Still writing|STARTED|Detected") {
            $status = "Idle - all caught up"; $statusColor = "Green"
        } else {
            $status = "Working..."; $statusColor = "Yellow"
        }
    } else {
        $status = "Waiting for first activity..."; $statusColor = "Gray"
    }

    $lifetimeGB = [math]::Round((Get-LifetimeTotal), 2)
    $prog = Get-Progress

    $localFiles = @(Get-ChildItem -Path $WatchFolder -Filter "*$FileExt" -File -ErrorAction SilentlyContinue)
    $localCount = $localFiles.Count
    $localGB = if ($localCount -gt 0) { [math]::Round(($localFiles | Measure-Object -Property Length -Sum).Sum / 1GB, 2) } else { 0 }

    $time = Get-Date -Format "HH:mm:ss"

    if ($prog.Active) {
        $upSpeed = $prog.Speed; $upPct = $prog.Percent; $upEta = $prog.Eta; $upColor = "Cyan"
    } else {
        $upSpeed = "(nothing uploading)"; $upPct = "-"; $upEta = "-"; $upColor = "DarkGray"
    }

    # Clear and redraw -- works in every terminal, guaranteed no spam
    Clear-Host

    Write-Host "===============================================" -ForegroundColor White
    Write-Host "       OBS Uploader - Live Dashboard" -ForegroundColor White
    Write-Host "          Developed by PawelPL101" -ForegroundColor Magenta
    Write-Host "                  v1.0.0" -ForegroundColor DarkGray
    Write-Host "===============================================" -ForegroundColor White
    Write-Host "  Updated: $time" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  --- Upload Stats ---" -ForegroundColor White
    Write-Host "  Chunks completed   : $completed" -ForegroundColor Cyan
    Write-Host "  Local files deleted: $deleted" -ForegroundColor Cyan
    Write-Host "  This session       : $sessionGB GB" -ForegroundColor Cyan
    Write-Host "  All-time total     : $lifetimeGB GB" -ForegroundColor Green
    Write-Host "  Errors (this run)  : $errors" -ForegroundColor $(if ($errors -gt 0) { "Red" } else { "Cyan" })
    Write-Host ""
    Write-Host "  --- Local Storage ---" -ForegroundColor White
    Write-Host "  Files waiting now  : $localCount" -ForegroundColor Cyan
    Write-Host "  Space used locally : $localGB GB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --- Current Upload ---" -ForegroundColor White
    Write-Host "  Speed              : $upSpeed" -ForegroundColor $upColor
    Write-Host "  Progress           : $upPct" -ForegroundColor $upColor
    Write-Host "  ETA                : $upEta" -ForegroundColor $upColor
    Write-Host ""
    Write-Host "  --- Status ---" -ForegroundColor White
    Write-Host "  $status" -ForegroundColor $statusColor
    Write-Host ""
    Write-Host "  Last log entry:" -ForegroundColor DarkGray
    Write-Host "  $lastLine" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Refreshes live. Close window to exit." -ForegroundColor DarkGray
    Write-Host "  (Closing this does NOT stop uploads)" -ForegroundColor DarkGray

    Start-Sleep -Seconds 2
}
