# =============================================================================
# OBS Chunk Auto-Uploader
# Copyright (c) 2026 PawelPL101
# Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
# NOT distribute modified versions. See LICENSE.txt for full terms.
# =============================================================================
# Stop-Uploader.ps1
# Detects whether the watcher is running, reports status, and stops it.
# Called by STOP-Uploader.bat. Keeping this logic in a .ps1 avoids the
# batch-quoting issues that mangle $_ when written inline in a .bat file.
# =============================================================================

param([string]$ConfigPath)

# Find the running watcher process (if any)
$watcher = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*Watch-OBSChunks.ps1*' }

if (-not $watcher) {
    Write-Host "  The uploader is not running - it's already stopped." -ForegroundColor Cyan
    return
}

# It's running - check the latest log activity to see if it's mid-upload
Write-Host "Checking upload status..." -ForegroundColor Gray
Write-Host ""

$busy = $false
try {
    . (Join-Path $PSScriptRoot "Load-Config.ps1")
    $cfg = Get-OBSConfig $ConfigPath
    $log = Join-Path $cfg["WatchFolder"] "upload-log.txt"
    $lines = Get-Content $log -Tail 30 -ErrorAction SilentlyContinue
    $last = $lines | Where-Object { $_ -notmatch '-{10,}' } | Select-Object -Last 1
    Write-Host "Last activity:" -ForegroundColor Gray
    Write-Host "  $last" -ForegroundColor Gray
    Write-Host ""
    if ($last -match 'IDLE|PIPELINE COMPLETE|Polling|Still writing|STARTED|LOCAL DELETE') {
        Write-Host "  ALL CLEAR - Safe to stop." -ForegroundColor Green
    } else {
        Write-Host "  UPLOAD IN PROGRESS - stopping now will interrupt it." -ForegroundColor Yellow
        $busy = $true
    }
} catch {
    Write-Host "  (Could not read log - proceeding anyway.)" -ForegroundColor DarkGray
}

Write-Host ""
$confirm = Read-Host "Stop the uploader now? (y/n)"
if ($confirm -ne "y") {
    Write-Host ""
    Write-Host "Cancelled. Uploader is still running." -ForegroundColor Gray
    return
}

# Stop the watcher process(es)
$watcher = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*Watch-OBSChunks.ps1*' }
foreach ($w in $watcher) {
    Stop-Process -Id $w.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host ""
if ($busy) {
    Write-Host "  Uploader stopped. The chunk that was uploading is STILL on your" -ForegroundColor Yellow
    Write-Host "  local drive (not interrupted in the cloud). It will upload again" -ForegroundColor Yellow
    Write-Host "  next time you start the uploader." -ForegroundColor Yellow
} else {
    Write-Host "  Uploader stopped. All footage is stored safely in your cloud storage." -ForegroundColor Green
}
