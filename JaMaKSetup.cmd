@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "SETUP_PS1=%SCRIPT_DIR%JaMaKSetup.ps1"

if not exist "%SETUP_PS1%" (
  echo Downloading JaMaK installer script...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/M1LESBETTER/JaMaK_release/main/JaMaKSetup.ps1' -OutFile '%SETUP_PS1%'"
  if errorlevel 1 (
    echo Could not download JaMaKSetup.ps1.
    pause
    exit /b 1
  )
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%SETUP_PS1%" %*
