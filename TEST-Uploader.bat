@echo off
REM =============================================================================
REM OBS Chunk Auto-Uploader (Version 1.0.2)
REM Copyright (c) 2026 PawelPL101
REM Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
REM NOT distribute modified versions. See LICENSE.txt for full terms.
REM =============================================================================
REM TEST-Uploader.bat - Verifies your setup works end to end.
REM Uploads a small test file, checks it, and cleans up. Run this after SETUP
REM to confirm everything is configured correctly before recording.
REM =============================================================================

echo ===============================================
echo        OBS Uploader - Setup Test
echo                  v1.0.2
echo ===============================================
echo.

REM Make sure setup has been run first
if not exist "%~dp0config.txt" goto NOCONFIG
goto RUNTEST

:NOCONFIG
echo   The uploader isn't set up yet, so there's nothing to test.
echo   Please run SETUP.bat first, then run this test.
echo.
pause
exit /b 1

:RUNTEST
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Test-Pipeline.ps1"
