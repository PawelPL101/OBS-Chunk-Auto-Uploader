@echo off
REM =============================================================================
REM OBS Chunk Auto-Uploader (Version 1.0.0)
REM Copyright (c) 2026 PawelPL101
REM Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
REM NOT distribute modified versions. See LICENSE.txt for full terms.
REM =============================================================================

echo ===============================================
echo        OBS Chunk Uploader - Starting...
echo                  v1.0.0
echo ===============================================
echo.

REM Verify setup has been run
if not exist "%~dp0config.txt" goto NOCONFIG
goto HASCONFIG

:NOCONFIG
echo   Looks like this is your first time - the uploader isn't set up yet.
echo.
echo   Please run SETUP.bat first. It only takes a minute and walks you
echo   through everything. Once that's done, run START-Uploader again
echo   to begin uploading.
echo.
pause
exit /b 1

:HASCONFIG

REM Archive the previous session's log using paths from config.txt.
powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%~dp0scripts\Load-Config.ps1'; $c = Get-OBSConfig '%~dp0config.txt'; $log = Join-Path $c.WatchFolder 'upload-log.txt'; $arc = Join-Path $c.WatchFolder 'log-archive'; if (-not (Test-Path $arc)) { New-Item -ItemType Directory -Path $arc -Force | Out-Null }; if (Test-Path $log) { $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'; Move-Item $log (Join-Path $arc ('upload-log-' + $stamp + '.txt')) -Force }"

echo Previous log archived. Starting fresh session.
echo.

REM Launch the watcher hidden in the background using a VBScript shim.
echo Set WshShell = CreateObject("WScript.Shell") > "%TEMP%\obs-launch.vbs"
echo WshShell.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File ""%~dp0scripts\Watch-OBSChunks.ps1""", 0, False >> "%TEMP%\obs-launch.vbs"
cscript //nologo "%TEMP%\obs-launch.vbs"
del "%TEMP%\obs-launch.vbs"

echo Uploader running in background.
echo Opening live dashboard...
timeout /t 2 /nobreak >nul

REM Run the dashboard in THIS window.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Dashboard.ps1"
