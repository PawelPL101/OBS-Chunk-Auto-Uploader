# =============================================================================
# OBS Chunk Auto-Uploader (Version 1.0.2)
# Copyright (c) 2026 PawelPL101
# Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
# NOT distribute modified versions. See LICENSE.txt for full terms.
# =============================================================================
# Load-Config.ps1
# Shared helper: reads config.txt (next to this script) into a hashtable.
# All other scripts dot-source this to get user settings.
# =============================================================================

function Get-OBSConfig {
    param([string]$ConfigPath)

    if (-not $ConfigPath) {
        # Scripts live in the "scripts" subfolder; config.txt is in the PARENT
        # (the main app folder). Resolve it relative to this script's location.
        $parent = Split-Path $PSScriptRoot -Parent
        $ConfigPath = Join-Path $parent "config.txt"
    }

    if (-not (Test-Path $ConfigPath)) {
        Write-Host "ERROR: config.txt not found at $ConfigPath" -ForegroundColor Red
        Write-Host "Please run SETUP.bat first to create your configuration." -ForegroundColor Yellow
        exit 1
    }

    $config = @{}
    foreach ($line in Get-Content $ConfigPath) {
        $trimmed = $line.Trim()
        # Skip blank lines and comments
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        # Parse Key=Value (split on the FIRST = only, so values can contain =)
        $idx = $trimmed.IndexOf("=")
        if ($idx -gt 0) {
            $key = $trimmed.Substring(0, $idx).Trim()
            $val = $trimmed.Substring($idx + 1).Trim()
            $config[$key] = $val
        }
    }

    # Provide sensible defaults for optional values
    if (-not $config.ContainsKey("FileExtension"))   { $config["FileExtension"] = ".mkv" }
    if (-not $config.ContainsKey("StabilitySeconds")) { $config["StabilitySeconds"] = "30" }
    if (-not $config.ContainsKey("NetworkAdapter"))  { $config["NetworkAdapter"] = "" }

    return $config
}
