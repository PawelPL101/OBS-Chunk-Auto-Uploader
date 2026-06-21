# =============================================================================
# OBS Chunk Auto-Uploader (Version 1.0.2)
# Copyright (c) 2026 PawelPL101
# Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
# NOT distribute modified versions. See LICENSE.txt for full terms.
# =============================================================================
# Test-Pipeline.ps1
# Verifies your setup works: uploads a small test file, checks it, deletes it.
# Run this after SETUP to confirm everything is configured correctly.
# =============================================================================

# Load user settings from config.txt
. (Join-Path $PSScriptRoot "Load-Config.ps1")
$cfg = Get-OBSConfig

$WatchFolder  = $cfg["WatchFolder"]
$RcloneRemote = $cfg["RcloneRemote"]
$RclonePath   = $cfg["RclonePath"]
$RemoteName   = ($RcloneRemote -split ":")[0]

$testFile = Join-Path $WatchFolder "PIPELINE-TEST-$(Get-Date -Format 'yyyyMMdd-HHmmss').mkv"
$pass = 0; $fail = 0

function Test-Step {
    param([string]$Name, [scriptblock]$Block)
    Write-Host "`n[$Name]" -ForegroundColor Cyan
    try {
        $result = & $Block
        if ($result -eq $false) {
            Write-Host "  FAIL" -ForegroundColor Red; $script:fail++
        } else {
            Write-Host "  PASS" -ForegroundColor Green; $script:pass++
        }
    } catch {
        Write-Host "  FAIL: $_" -ForegroundColor Red; $script:fail++
    }
}

Test-Step "rclone exists" {
    $v = & $RclonePath version 2>&1 | Select-Object -First 1
    Write-Host "  $v"
    $v -match "rclone"
}

Test-Step "Cloud remote accessible" {
    & $RclonePath lsd "$RemoteName`:" --max-depth 1 2>&1 | Out-Null
    $LASTEXITCODE -eq 0
}

Test-Step "Create test file (50 MB)" {
    $bytes = New-Object byte[] (50MB)
    [System.IO.File]::WriteAllBytes($testFile, $bytes)
    Test-Path $testFile
}

Test-Step "Upload to cloud" {
    $argString = 'copy "{0}" "{1}" --log-level INFO' -f $testFile, $RcloneRemote
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $RclonePath
    $psi.Arguments = $argString
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    $p.ExitCode -eq 0
}

Test-Step "Checksum verification" {
    # Verify just the one test file: compare its remote hash to the local hash.
    # Using 'check' with both paths narrowed to the single filename avoids false
    # mismatches from other files in the folder.
    $fileName = Split-Path $testFile -Leaf
    $argString = 'check "{0}" "{1}" --one-way --include "{2}"' -f $WatchFolder, $RcloneRemote, $fileName
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $RclonePath
    $psi.Arguments = $argString
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardError = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $errOut = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { Write-Host "  $errOut" -ForegroundColor DarkGray }
    $p.ExitCode -eq 0
}

Test-Step "Delete local test file" {
    Remove-Item $testFile -Force
    -not (Test-Path $testFile)
}

Test-Step "Remote copy still exists, then clean up" {
    $fileName = Split-Path $testFile -Leaf
    $out = & $RclonePath ls "$RcloneRemote/$fileName" 2>&1
    & $RclonePath deletefile "$RcloneRemote/$fileName" 2>&1 | Out-Null
    $out -match "\d"
}

Write-Host "`n============================================" -ForegroundColor White
Write-Host "  Results: $pass passed, $fail failed" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
Write-Host "============================================" -ForegroundColor White
if ($fail -eq 0) {
    Write-Host "`n  All tests passed! You're ready to record.`n" -ForegroundColor Green
} else {
    Write-Host "`n  Some tests failed - check your config.txt and rclone setup.`n" -ForegroundColor Yellow
}
Read-Host "Press Enter to exit"
