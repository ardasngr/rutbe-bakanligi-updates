@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0KURULUM_BIR_KEZ.ps1"
if errorlevel 1 (
  echo.
  echo Kurulum tamamlanamadi. Ayrintilar yukaridaki PowerShell mesajinda.
  pause
)
endlocal
