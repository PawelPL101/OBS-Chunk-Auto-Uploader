@echo off
REM =============================================================================
REM OBS Chunk Auto-Uploader (Version 1.0.1)
REM Copyright (c) 2026 PawelPL101
REM Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
REM NOT distribute modified versions. See LICENSE.txt for full terms.
REM =============================================================================

echo ===============================================
echo        OBS Uploader - Stop
echo                v1.0.1
echo ===============================================
echo.

REM Detection and stopping are handled entirely by a PowerShell helper script.
REM Keeping the logic in a .ps1 file avoids the batch-vs-PowerShell quoting
REM problems that mangle $_ when written inline in a .bat.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Stop-Uploader.ps1" "%~dp0config.txt"

echo.
pause
