@echo off
REM =============================================================================
REM OBS Chunk Auto-Uploader
REM Copyright (c) 2026 PawelPL101
REM Licensed under CC BY-ND 4.0 - You may use and share this file, but you may
REM NOT distribute modified versions. See LICENSE.txt for full terms.
REM =============================================================================
REM SETUP.bat - Double-click this to set up the uploader on your PC.
REM It auto-detects your system and walks you through configuration.
REM =============================================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Setup-Wizard.ps1"
