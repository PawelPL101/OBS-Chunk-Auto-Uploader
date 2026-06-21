# =============================================================================
# OBS Chunk Auto-Uploader (Version 1.0.2)
# Copyright (c) 2026 PawelPL101
# Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
# NOT distribute modified versions. See LICENSE.txt for full terms.
# =============================================================================

# =============================================================================
# Watch-OBSChunks.ps1
# OBS Chunk Auto-Uploader: Watch -> Upload -> Verify -> Delete
# Single-loop design (no background runspace). Simple and robust.
# =============================================================================

# Load user settings from config.txt
. (Join-Path $PSScriptRoot "Load-Config.ps1")
$cfg = Get-OBSConfig

# The app's root folder is the parent of this scripts/ folder.
$AppRoot   = Split-Path $PSScriptRoot -Parent
$DataDir   = Join-Path $AppRoot "data"
if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }

$WatchFolder         = $cfg["WatchFolder"]
$RcloneRemote        = $cfg["RcloneRemote"]
$RclonePath          = $cfg["RclonePath"]
$StabilitySeconds    = [int]$cfg["StabilitySeconds"]
$PollIntervalSeconds = 10
$LogFile             = Join-Path $WatchFolder "upload-log.txt"
$StatsFile           = Join-Path $DataDir "lifetime-stats.txt"
$ProgressFile        = Join-Path $DataDir "progress.txt"
$RcloneLog           = Join-Path $DataDir "rclone-current.log"
$Extensions          = @($cfg["FileExtension"])

$RcloneTransferArgs = @(
    "--transfers", "1",
    "--drive-chunk-size", "256M",
    "--drive-upload-cutoff", "256M",
    "--retries", "5",
    "--low-level-retries", "10",
    "--stats", "2s",
    "--stats-log-level", "NOTICE",
    "--log-level", "INFO"
)

# Track files already handled this session
# Files we've permanently given up on after repeated failures (still on disk).
# We deliberately do NOT track successfully-uploaded files, because those get
# deleted - so a fresh file with the same name is correctly treated as new.
$GaveUp = New-Object System.Collections.Generic.HashSet[string]

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    $color = "Cyan"
    if ($Level -eq "ERROR")   { $color = "Red" }
    if ($Level -eq "WARN")    { $color = "Yellow" }
    if ($Level -eq "SUCCESS") { $color = "Green" }
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}

function Test-FileStable {
    param([string]$FilePath)

    # Check 1: exclusive open. OBS holds a write lock while recording.
    try {
        $stream = [System.IO.File]::Open($FilePath, 'Open', 'Read', 'None')
        $stream.Close()
        $stream.Dispose()
    } catch {
        return $false
    }

    # Check 2: size stable over StabilitySeconds
    $size1 = (Get-Item $FilePath).Length
    Start-Sleep -Seconds $StabilitySeconds
    if (-not (Test-Path $FilePath)) { return $false }
    $size2 = (Get-Item $FilePath).Length

    return (($size1 -eq $size2) -and ($size1 -gt 0))
}

function Invoke-Upload {
    param([string]$FilePath)
    $fileName = Split-Path $FilePath -Leaf
    $fileSize = [math]::Round((Get-Item $FilePath).Length / 1GB, 2)
    Write-Log "UPLOAD START: $fileName ($fileSize GB)"

    Set-Content -Path $ProgressFile -Value "UPLOADING|$fileName|starting..." -ErrorAction SilentlyContinue

    # Build a single argument string, quoting paths that may contain spaces.
    # (Windows PowerShell 5.1 lacks ProcessStartInfo.ArgumentList, so we use the
    # .Arguments string property with manual quoting -- confirmed working.)
    $transferArgString = ($RcloneTransferArgs -join " ")
    $argString = 'copy "{0}" "{1}" {2}' -f $FilePath, $RcloneRemote, $transferArgString

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $RclonePath
    $psi.Arguments = $argString
    $psi.RedirectStandardError  = $true
    $psi.RedirectStandardOutput = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    # Shared store the event handler writes the latest stat line to.
    # Also accumulate ALL stderr so we can log the real error on failure.
    $shared = [hashtable]::Synchronized(@{ LastStat = ""; AllErr = New-Object System.Collections.ArrayList })
    $errHandler = {
        if ($Event.SourceEventArgs.Data) {
            $d = $Event.SourceEventArgs.Data
            [void]$Event.MessageData.AllErr.Add($d)
            # Only accept the BYTE-transfer stats line (has a data-size unit like
            # GiB/MiB/KiB before the percentage). This excludes the "0 / 1, 0%"
            # file-COUNT line that otherwise causes the percentage to flicker to 0.
            if ($d -match "Transferred:\s+[\d\.]+\s*[KMGT]?i?B\s*/" -and $d -match "\d+%") {
                $Event.MessageData.LastStat = $d
            }
        }
    }
    Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action $errHandler -MessageData $shared | Out-Null

    $proc.Start() | Out-Null
    $proc.BeginErrorReadLine()
    $proc.BeginOutputReadLine()

    # Poll and publish the latest stat line while rclone runs
    while (-not $proc.HasExited) {
        Start-Sleep -Seconds 1
        if ($shared.LastStat -ne "") {
            Set-Content -Path $ProgressFile -Value "UPLOADING|$fileName|$($shared.LastStat)" -ErrorAction SilentlyContinue
        }
    }
    $proc.WaitForExit()
    $code = $proc.ExitCode

    # Clean up the event subscription
    Get-EventSubscriber | Where-Object { $_.SourceObject -eq $proc } | Unregister-Event -ErrorAction SilentlyContinue

    Set-Content -Path $ProgressFile -Value "IDLE||" -ErrorAction SilentlyContinue

    if ($code -ne 0) {
        Write-Log "UPLOAD FAILED (exit $code): $fileName" "ERROR"
        # Log the last few stderr lines so we can see WHY it failed
        $errLines = $shared.AllErr | Select-Object -Last 5
        foreach ($e in $errLines) {
            Write-Log "  rclone: $e" "ERROR"
        }
        return $false
    }
    Write-Log "UPLOAD COMPLETE: $fileName" "SUCCESS"
    return $true
}

function Invoke-Verify {
    param([string]$FilePath)
    $fileName = Split-Path $FilePath -Leaf
    $localDir = Split-Path $FilePath -Parent
    Write-Log "VERIFY START: $fileName"

    $rcArgs = @("check", $localDir, $RcloneRemote, "--one-way", "--include", $fileName, "--log-level", "INFO")
    & $RclonePath @rcArgs
    $code = $LASTEXITCODE

    if ($code -ne 0) {
        Write-Log "VERIFY FAILED (checksum mismatch or missing): $fileName" "ERROR"
        return $false
    }
    Write-Log "VERIFY PASSED (checksum OK): $fileName" "SUCCESS"
    return $true
}

function Remove-Local {
    param([string]$FilePath)
    $fileName = Split-Path $FilePath -Leaf
    try {
        Remove-Item -Path $FilePath -Force -ErrorAction Stop
        Write-Log "LOCAL DELETE: $fileName (cloud copy safe)" "SUCCESS"
        return $true
    } catch {
        Write-Log "DELETE FAILED: $fileName - $_" "ERROR"
        return $false
    }
}

function Update-LifetimeTotal {
    param([double]$AddGB)
    $current = 0.0
    if (Test-Path $StatsFile) {
        try { $current = [double](Get-Content $StatsFile -Raw).Trim() } catch { $current = 0.0 }
    }
    $new = [math]::Round($current + $AddGB, 2)
    Set-Content -Path $StatsFile -Value $new -ErrorAction SilentlyContinue
}

function Invoke-Pipeline {
    param([string]$FilePath)
    $fileName = Split-Path $FilePath -Leaf

    # Capture size before any deletion happens
    $sizeGB = [math]::Round((Get-Item $FilePath).Length / 1GB, 2)

    Write-Log "PIPELINE START: $fileName"

    if (-not (Invoke-Upload -FilePath $FilePath)) {
        Write-Log "PIPELINE ABORTED at upload: $fileName" "WARN"
        return $false
    }
    if (-not (Invoke-Verify -FilePath $FilePath)) {
        Write-Log "PIPELINE ABORTED at verify - LOCAL FILE KEPT: $fileName" "WARN"
        return $false
    }
    Remove-Local -FilePath $FilePath | Out-Null

    # Only count toward lifetime total after a fully successful pipeline
    Update-LifetimeTotal -AddGB $sizeGB

    Write-Log "PIPELINE COMPLETE: $fileName" "SUCCESS"
    Write-Log "---------------------------------------------------"
    return $true
}

# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------
Write-Log "========================================================"
Write-Log "OBS Chunk Auto-Uploader STARTED"
Write-Log "Watching : $WatchFolder"
Write-Log "Remote   : $RcloneRemote"
Write-Log "Stability: $StabilitySeconds s"
Write-Log "========================================================"

if (-not (Test-Path $RclonePath)) {
    Write-Log "rclone not found at '$RclonePath'" "ERROR"
    exit 1
}
if (-not (Test-Path $WatchFolder)) {
    New-Item -ItemType Directory -Path $WatchFolder -Force | Out-Null
    Write-Log "Created watch folder: $WatchFolder"
}

Write-Log "Polling every $PollIntervalSeconds s..."

# Clear any stale progress from a previous session (e.g. if the watcher was
# stopped mid-upload). This ensures the dashboard starts in a clean idle state.
Set-Content -Path $ProgressFile -Value "IDLE||" -ErrorAction SilentlyContinue

# Track retry counts per file so a permanently-broken file doesn't loop forever
$RetryCount = @{}
$MaxRetries = 3

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
while ($true) {
    $files = Get-ChildItem -Path $WatchFolder -File | Where-Object { $Extensions -contains $_.Extension }
    $didWork = $false

    # Prune Done/Retry entries for files that no longer exist, so a NEW file with
    # the same name (e.g. a fresh dummy-test.mkv) gets picked up without a restart.
    $currentPaths = @($files | ForEach-Object { $_.FullName })
    foreach ($tracked in @($GaveUp)) {
        if ($currentPaths -notcontains $tracked) { $null = $GaveUp.Remove($tracked) }
    }
    foreach ($tracked in @($RetryCount.Keys)) {
        if ($currentPaths -notcontains $tracked) { $RetryCount.Remove($tracked) }
    }

    foreach ($file in $files) {
        $path = $file.FullName
        # Skip only files we've permanently given up on (still on disk)
        if ($GaveUp.Contains($path)) { continue }

        Write-Log "Detected: $($file.Name) - checking if finished..."

        if (Test-FileStable -FilePath $path) {
            Write-Log "Stable - processing: $($file.Name)"
            $success = Invoke-Pipeline -FilePath $path
            $didWork = $true

            if ($success) {
                # File is now deleted (successful pipeline) - nothing to track.
                if ($RetryCount.ContainsKey($path)) { $RetryCount.Remove($path) }
            } else {
                # Track retries; give up after MaxRetries so we don't loop forever
                if (-not $RetryCount.ContainsKey($path)) { $RetryCount[$path] = 0 }
                $RetryCount[$path]++
                if ($RetryCount[$path] -ge $MaxRetries) {
                    Write-Log "GAVE UP after $MaxRetries attempts (file kept locally): $($file.Name)" "ERROR"
                    $null = $GaveUp.Add($path)
                } else {
                    Write-Log "Will retry ($($RetryCount[$path])/$MaxRetries) next cycle: $($file.Name)" "WARN"
                }
            }
        } else {
            Write-Log "Still writing (OBS active): $($file.Name)"
        }
    }

    # Heartbeat so the dashboard can reliably show an idle state
    if (-not $didWork) {
        Write-Log "IDLE - waiting for next chunk" "INFO"
    }

    Start-Sleep -Seconds $PollIntervalSeconds
}
