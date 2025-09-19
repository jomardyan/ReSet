@echo off
:: ReSet Toolkit - Administrator Console Launcher
:: Professional launcher for the PowerShell admin interface

setlocal EnableDelayedExpansion

echo.
echo ===============================================
echo   ReSet Toolkit - Administrator Console
echo ===============================================
echo.

:: Check administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Administrator privileges required.
    echo.
    echo Please right-click this file and select "Run as administrator"
    echo or use: Start-Process cmd -Verb RunAs
    echo.
    pause
    exit /b 1
)

:: Set up paths
set "ROOT=%~dp0"
set "CLI_SCRIPT=%ROOT%cli\ReSetCLI.ps1"

:: Validate CLI script exists
if not exist "%CLI_SCRIPT%" (
    echo [ERROR] CLI script not found: %CLI_SCRIPT%
    echo Please ensure ReSet Toolkit is properly installed.
    echo.
    pause
    exit /b 2
)

:: Display system info
echo [INFO] Launching Administrator Console...
echo [INFO] Computer: %COMPUTERNAME%
echo [INFO] User: %USERDOMAIN%\%USERNAME%
echo [INFO] Time: %DATE% %TIME%
echo.

:: Check PowerShell availability and version
echo [INFO] Checking PowerShell environment...

:: Prefer PowerShell 7+ (pwsh) for best experience
where pwsh >nul 2>&1
if %errorlevel% equ 0 (
    echo [INFO] Using PowerShell 7+ ^(pwsh^) - Enhanced experience
    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%CLI_SCRIPT%" %*
    set "PS_EXIT=%errorlevel%"
) else (
    :: Fallback to Windows PowerShell 5.1
    echo [INFO] Using Windows PowerShell 5.1 - Standard experience
    powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%CLI_SCRIPT%" %*
    set "PS_EXIT=%errorlevel%"
)

:: Handle exit codes
echo.
if %PS_EXIT% equ 0 (
    echo [SUCCESS] Administrator Console session completed successfully.
) else (
    echo [WARNING] Console exited with code: %PS_EXIT%
    echo This may indicate an error or unexpected termination.
)

echo.
echo Press any key to close this window...
pause >nul

endlocal
exit /b %PS_EXIT%