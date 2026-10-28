@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0OneClick.ps1" -CursorPath "%~1"
echo.
pause
