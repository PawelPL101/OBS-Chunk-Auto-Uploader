# =============================================================================
# OBS Chunk Auto-Uploader (Version 1.0.2)
# Copyright (c) 2026 PawelPL101
# Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
# NOT distribute modified versions. See LICENSE.txt for full terms.
# =============================================================================
# Setup-Wizard.ps1
# Interactive setup: auto-detects system info, asks the user a few questions,
# and writes config.txt. Launched by SETUP.bat.
# =============================================================================

# This wizard lives in scripts/; the app root is its parent. config.txt and the
# data/ folder live in the app root so users can find them easily.
$AppRoot      = Split-Path $PSScriptRoot -Parent
$ScriptFolder = $AppRoot
$ConfigPath   = Join-Path $AppRoot "config.txt"

function Title { param($t) Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Good  { param($t) Write-Host "  [OK] $t" -ForegroundColor Green }
function Warn  { param($t) Write-Host "  [!] $t" -ForegroundColor Yellow }
function Info  { param($t) Write-Host "  $t" -ForegroundColor Gray }

Clear-Host
Write-Host "===============================================" -ForegroundColor White
Write-Host "   OBS Chunk Auto-Uploader - Setup Wizard" -ForegroundColor White
Write-Host "          Developed by PawelPL101" -ForegroundColor Magenta
Write-Host "                  v1.0.2" -ForegroundColor DarkGray
Write-Host "===============================================" -ForegroundColor White
Write-Host ""
Write-Host "This wizard will detect your system and set up the uploader." -ForegroundColor Gray
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Check for rclone
# ---------------------------------------------------------------------------
Title "Step 1: Checking for rclone"

$rclonePath = ""
# Check PATH first (works regardless of which drive rclone is on), then the
# common fixed locations.
$candidates = @("C:\rclone\rclone.exe", "C:\Program Files\rclone\rclone.exe")
$inPath = Get-Command rclone -ErrorAction SilentlyContinue
if ($inPath) { $candidates = @($inPath.Source) + $candidates }

foreach ($c in $candidates) {
    if (Test-Path $c) { $rclonePath = $c; break }
}

# If not auto-found, let the user point us to it (covers D:, E:, custom folders)
if ($rclonePath -eq "") {
    Warn "rclone was not auto-detected in the usual places."
    Write-Host ""
    Write-Host "  If you HAVE installed rclone (e.g. on another drive like D:)," -ForegroundColor Gray
    Write-Host "  you can tell me where rclone.exe is right now." -ForegroundColor Gray
    Write-Host "  Otherwise, read 'how-to-install-rclone.txt' to install it first." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Enter the FULL path to rclone.exe, or just press Enter to exit." -ForegroundColor Gray
    Write-Host "  Example: D:\rclone\rclone.exe" -ForegroundColor DarkGray
    Write-Host ""

    $tries = 0
    while ($rclonePath -eq "" -and $tries -lt 3) {
        $manual = Read-Host "  Path to rclone.exe"
        $manual = $manual.Trim().Trim('"')
        if ($manual -eq "") { break }
        if (Test-Path $manual) {
            # Make sure it's actually rclone
            $test = (& $manual version 2>$null | Select-Object -First 1)
            if ($test -match "rclone") {
                $rclonePath = $manual
            } else {
                Warn "That file doesn't look like rclone. Try again."
            }
        } else {
            Warn "No file found at that path. Try again."
        }
        $tries++
    }
}

if ($rclonePath -eq "") {
    Write-Host ""
    Write-Host "  rclone is required for this tool to work." -ForegroundColor Yellow
    Write-Host "  Please read 'how-to-install-rclone.txt' for the install guide," -ForegroundColor Yellow
    Write-Host "  then run this SETUP again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
} else {
    Good "Found rclone at: $rclonePath"
    $ver = (& $rclonePath version 2>$null | Select-Object -First 1)
    Info $ver
}

# ---------------------------------------------------------------------------
# 2. Auto-detect network adapter
# ---------------------------------------------------------------------------
Title "Step 2: Detecting your network adapter"

$adapter = ""
try {
    # Pick the active adapter with the most traffic (the real internet connection)
    $active = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } |
              Sort-Object -Property { (Get-NetAdapterStatistics -Name $_.Name -ErrorAction SilentlyContinue).ReceivedBytes } -Descending |
              Select-Object -First 1
    if ($active) {
        $adapter = $active.Name
        Good "Detected active adapter: $adapter"
    }
} catch { }

if ($adapter -eq "") {
    Warn "Could not auto-detect adapter. Upload speed display may not work."
    $adapter = "Ethernet"
}

# ---------------------------------------------------------------------------
# 3. Ask for OBS recording folder
# ---------------------------------------------------------------------------
Title "Step 3: Where does OBS save your recordings?"

Write-Host "  Enter the FULL path to your OBS recording folder." -ForegroundColor Gray
Write-Host "  (In OBS: Settings -> Output -> Recording -> Recording Path)" -ForegroundColor DarkGray
Write-Host "  Example: D:\OBS Recordings" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  IMPORTANT: Do NOT use a folder inside OneDrive, or your Windows" -ForegroundColor Yellow
Write-Host "  Videos / Documents / Desktop folders (these are often synced by" -ForegroundColor Yellow
Write-Host "  OneDrive). Use a plain folder on a disk, like D:\OBS Recordings." -ForegroundColor Yellow
Write-Host ""

$watchFolder = ""
while ($watchFolder -eq "") {
    $entered = Read-Host "  OBS recording folder"
    $entered = $entered.Trim('"').Trim()
    if ($entered -eq "") { $entered = "D:\OBS Recordings" }

    # Detect OneDrive / known auto-synced locations that break the uploader.
    $lower = $entered.ToLower()
    $risky = $false
    if ($lower -like "*onedrive*") { $risky = $true }
    if ($env:OneDrive -and $lower.StartsWith($env:OneDrive.ToLower())) { $risky = $true }
    # Default user media folders are commonly redirected into OneDrive
    foreach ($bad in @("\users\*\videos", "\users\*\documents", "\users\*\desktop", "\users\*\pictures")) {
        if ($lower -like "*$bad*") { $risky = $true }
    }

    if ($risky) {
        Write-Host ""
        Warn "That folder looks like it may be inside OneDrive or a synced"
        Warn "Windows folder. This is known to BREAK uploads - OneDrive fights"
        Warn "with the uploader over the same files."
        Write-Host ""
        Write-Host "  Strongly recommended: pick a plain folder on a disk instead," -ForegroundColor Yellow
        Write-Host "  for example D:\OBS Recordings (NOT under your user profile)." -ForegroundColor Yellow
        Write-Host ""
        $useAnyway = Read-Host "  Use this folder anyway? (y = yes, n = pick a different one)"
        if ($useAnyway -eq "y") {
            $watchFolder = $entered
        }
        # if not 'y', loop again to re-enter
    } else {
        $watchFolder = $entered
    }
}

if (-not (Test-Path $watchFolder)) {
    Warn "That folder doesn't exist yet."
    $make = Read-Host "  Create it now? (y/n)"
    if ($make -eq "y") {
        New-Item -ItemType Directory -Path $watchFolder -Force | Out-Null
        Good "Created: $watchFolder"
    }
} else {
    Good "Folder exists: $watchFolder"
}

# ---------------------------------------------------------------------------
# 3b. Ask which recording format / extension to watch for
# ---------------------------------------------------------------------------
Title "Step 3b: Which recording format does OBS use?"

Write-Host "  Pick the file format you record in (must match your OBS setting)." -ForegroundColor Gray
Write-Host "  This is the file type the uploader will watch for and upload." -ForegroundColor DarkGray
Write-Host ""
Write-Host "    1. MKV   (recommended - crash-safe)" -ForegroundColor White
Write-Host "    2. MP4" -ForegroundColor White
Write-Host "    3. MOV" -ForegroundColor White
Write-Host "    4. FLV" -ForegroundColor White
Write-Host "    5. TS" -ForegroundColor White
Write-Host "    6. Other (type it yourself)" -ForegroundColor White
Write-Host ""
$fmtChoice = Read-Host "  Enter a number (1-6)"
switch ($fmtChoice.Trim()) {
    "1" { $fileExt = ".mkv" }
    "2" { $fileExt = ".mp4" }
    "3" { $fileExt = ".mov" }
    "4" { $fileExt = ".flv" }
    "5" { $fileExt = ".ts" }
    "6" {
        $custom = Read-Host "  Enter the extension (e.g. .webm)"
        $custom = $custom.Trim()
        if (-not $custom.StartsWith(".")) { $custom = "." + $custom }
        $fileExt = $custom.ToLower()
    }
    default { $fileExt = ".mkv"; Warn "Invalid choice - defaulting to MKV." }
}
Good "Watching for: $fileExt files"

# ---------------------------------------------------------------------------
# 4. Ask which cloud service, then the remote + folder
# ---------------------------------------------------------------------------
Title "Step 4: Cloud storage destination"

Write-Host "  Which cloud service are you uploading to?" -ForegroundColor Gray
Write-Host "  (This tool works with any service rclone supports.)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    1. Google Drive" -ForegroundColor White
Write-Host "    2. Dropbox" -ForegroundColor White
Write-Host "    3. OneDrive" -ForegroundColor White
Write-Host "    4. Backblaze B2" -ForegroundColor White
Write-Host "    5. Amazon S3" -ForegroundColor White
Write-Host "    6. Other (any rclone-supported provider)" -ForegroundColor White
Write-Host ""
$cloudChoice = Read-Host "  Enter a number (1-6)"
switch ($cloudChoice.Trim()) {
    "1" { $cloudName = "Google Drive"; $exampleRemote = "gdrive" }
    "2" { $cloudName = "Dropbox";      $exampleRemote = "dropbox" }
    "3" { $cloudName = "OneDrive";     $exampleRemote = "onedrive" }
    "4" { $cloudName = "Backblaze B2"; $exampleRemote = "b2" }
    "5" { $cloudName = "Amazon S3";    $exampleRemote = "s3" }
    "6" { $cloudName = "your cloud";   $exampleRemote = "myremote" }
    default { $cloudName = "your cloud"; $exampleRemote = "myremote"; Warn "Unrecognized - continuing generically." }
}
Good "Selected: $cloudName"
Write-Host ""

# Helper: get the current list of configured remote names (without colons)
function Get-RemoteList {
    $raw = (& $rclonePath listremotes 2>$null)
    if (-not $raw) { return @() }
    return @($raw | ForEach-Object { $_.Trim().TrimEnd(':') } | Where-Object { $_ -ne "" })
}

# You cannot continue past this point until at least one working remote exists
# AND you've selected it. This prevents finishing setup with no cloud connection.
$remoteName = ""
while ($remoteName -eq "") {
    $existing = Get-RemoteList

    if ($existing.Count -eq 0) {
        # No remotes at all - force the user to create one before continuing
        Write-Host ""
        Warn "No rclone remotes are set up yet."
        Write-Host "  You MUST create one before you can finish setup. This is what" -ForegroundColor Yellow
        Write-Host "  connects rclone to $cloudName." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  rclone config will now open. Follow the prompts (the guide" -ForegroundColor Gray
        Write-Host "  'how-to-install-rclone.txt' has detailed steps for $cloudName)." -ForegroundColor Gray
        Write-Host ""
        Read-Host "  Press Enter to open rclone config"
        & $rclonePath config

        # Re-check after they return from rclone config
        $existing = Get-RemoteList
        if ($existing.Count -eq 0) {
            Write-Host ""
            Warn "Still no remote found. You need to complete rclone config"
            Warn "(create a remote and finish the sign-in) before continuing."
            $retry = Read-Host "  Try again? (y = reopen rclone config, n = exit setup)"
            if ($retry -ne "y") {
                Write-Host ""
                Write-Host "  Setup cannot continue without a cloud remote. Exiting." -ForegroundColor Yellow
                Read-Host "  Press Enter to exit"
                exit 1
            }
            continue  # loop back, will reopen config
        }
    }

    # At least one remote exists - show them and let them pick
    Write-Host ""
    Info "Configured rclone remotes:"
    foreach ($r in $existing) { Info "   $r" }
    Write-Host ""
    Write-Host "  Type the remote name to use (without the colon)." -ForegroundColor Gray
    Write-Host "  Or type 'new' to create another one." -ForegroundColor DarkGray
    Write-Host "  Example: $exampleRemote" -ForegroundColor DarkGray
    Write-Host ""
    $entry = Read-Host "  Remote name"
    $entry = $entry.Trim().TrimEnd(':')

    if ($entry -eq "new") {
        & $rclonePath config
        continue  # loop back to re-list and pick
    }

    if ($entry -eq "") {
        Warn "Please type a remote name."
        continue
    }

    # Verify the typed name actually matches an existing remote
    if ($existing -contains $entry) {
        # Confirmed it exists - test that it actually responds
        Write-Host ""
        Info "Testing connection to '$entry'..."
        & $rclonePath lsd "$entry`:" --max-depth 1 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Good "Remote '$entry' is working!"
            $remoteName = $entry
        } else {
            Warn "Remote '$entry' exists but didn't respond. It may need"
            Warn "re-authentication."
            $fix = Read-Host "  Open rclone config to fix it? (y/n)"
            if ($fix -eq "y") { & $rclonePath config }
            # loop back either way
        }
    } else {
        Warn "'$entry' is not in your list of remotes. Type one of the names"
        Warn "shown above exactly, or type 'new' to create one."
    }
}

Write-Host ""
Write-Host "  Enter the folder name in your cloud to upload recordings into." -ForegroundColor Gray
Write-Host "  Example: OBS-Archive" -ForegroundColor DarkGray
$driveFolder = Read-Host "  Cloud folder"
$driveFolder = $driveFolder.Trim()
if ($driveFolder -eq "") { $driveFolder = "OBS-Archive" }

$rcloneRemote = "$remoteName`:$driveFolder"

# ---------------------------------------------------------------------------
# 5. Write config.txt
# ---------------------------------------------------------------------------
Title "Step 5: Saving your configuration"

$configContent = @"
# =============================================================================
# OBS Chunk Auto-Uploader - Configuration
# Copyright (c) 2026 PawelPL101 - CC BY-ND 4.0
# =============================================================================
# Created by SETUP. Edit manually only if your setup changes.
# Format: Setting=Value  (no spaces around the = sign)
# =============================================================================

WatchFolder=$watchFolder
ScriptFolder=$ScriptFolder
RcloneRemote=$rcloneRemote
RclonePath=$rclonePath
NetworkAdapter=$adapter
FileExtension=$fileExt
StabilitySeconds=30
"@

Set-Content -Path $ConfigPath -Value $configContent -Encoding UTF8
Good "Configuration saved to config.txt"

# ---------------------------------------------------------------------------
# 6. Test Drive access
# ---------------------------------------------------------------------------
Title "Step 6: Testing cloud access"

& $rclonePath lsd "$remoteName`:" --max-depth 1 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Good "$cloudName is accessible!"
} else {
    Warn "Could not reach $cloudName. You may need to (re)configure the remote."
    Info "Run: `"$rclonePath`" config"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "   SETUP COMPLETE!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Your settings:" -ForegroundColor White
Write-Host "    Recordings folder : $watchFolder" -ForegroundColor Gray
Write-Host "    Recording format  : $fileExt" -ForegroundColor Gray
Write-Host "    Upload to         : $rcloneRemote" -ForegroundColor Gray
Write-Host "    rclone            : $rclonePath" -ForegroundColor Gray
Write-Host "    Network adapter   : $adapter" -ForegroundColor Gray
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor White
Write-Host "    1. In OBS, set your recording path to match the folder above" -ForegroundColor Gray
Write-Host "    2. Enable: Settings -> Output -> Recording -> Split Recording" -ForegroundColor Gray
Write-Host "    3. Double-click START-Uploader.bat to begin!" -ForegroundColor Gray
Write-Host ""
Write-Host "  Found a bug? Email contact.pawelpl101@gmail.com" -ForegroundColor DarkGray
Write-Host ""
Read-Host "Press Enter to finish"
