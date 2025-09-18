@echo off
:: ReSet Toolkit GUI Launcher
:: Starts the PowerShell GUI application for the Windows Settings Reset Toolkit

setlocal EnableDelayedExpansion

:: Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] This application requires administrator privileges.
    echo Please run as administrator.
    echo.
    pause
    exit /b 1
)

:: Set up paths
set "SCRIPT_DIR=%~dp0"
set "GUI_SCRIPT=%SCRIPT_DIR%gui\ReSetGUI.ps1"

:: Check if GUI script exists
if not exist "%GUI_SCRIPT%" (
    echo [ERROR] GUI script not found: %GUI_SCRIPT%
    echo Please ensure the ReSet Toolkit is properly installed.
    echo.
    pause
    exit /b 1
)

:: Display banner
echo ===============================================
echo   ReSet Toolkit - GUI Application Launcher
echo ===============================================
echo.
echo Starting PowerShell GUI interface...
echo.

:: Check PowerShell version
powershell -Command "if ($PSVersionTable.PSVersion.Major -lt 5) { exit 1 }" >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] PowerShell 5.0 or higher is recommended for best experience.
    echo.
)

:: Launch PowerShell GUI with proper execution policy
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "%GUI_SCRIPT%"

:: Check if GUI exited with error
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] GUI application exited with error code: %errorlevel%
    echo.
    pause
)

endlocal