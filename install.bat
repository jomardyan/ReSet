@echo off
:: Windows Settings Reset Toolkit - Installation Script
:: Sets up the ReSet toolkit for first-time use

title ReSet Toolkit - Installation

echo.
echo =============================================
echo  Windows Settings Reset Toolkit (ReSet)
echo  Installation and Setup
echo =============================================
echo.

:: Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This installation requires Administrator privileges.
    echo Please right-click this script and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

:: Set installation directory
set "INSTALL_DIR=%~dp0"
set "SCRIPTS_DIR=%INSTALL_DIR%scripts"
set "LOGS_DIR=%INSTALL_DIR%logs"
set "BACKUPS_DIR=%INSTALL_DIR%backups"
set "DOCS_DIR=%INSTALL_DIR%docs"

echo Installing to: %INSTALL_DIR%
echo.

:: Create required directories
echo Creating directory structure...
if not exist "%SCRIPTS_DIR%" mkdir "%SCRIPTS_DIR%"
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
if not exist "%BACKUPS_DIR%" mkdir "%BACKUPS_DIR%"
if not exist "%DOCS_DIR%" mkdir "%DOCS_DIR%"

:: Initialize logging
for /f "tokens=2 delims==" %%i in ('wmic OS Get localdatetime /value') do set "dt=%%i"
set "YYYY=%dt:~0,4%"
set "MM=%dt:~4,2%"
set "DD=%dt:~6,2%"
set "LOG_FILE=%LOGS_DIR%\installation-%YYYY%-%MM%-%DD%.log"

echo [%date% %time%] Starting ReSet Toolkit installation >> "%LOG_FILE%"

:: Check Windows version compatibility
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo Checking Windows version... %VERSION%
echo [%date% %time%] Windows version detected: %VERSION% >> "%LOG_FILE%"

if "%VERSION%" neq "10.0" (
    echo WARNING: This toolkit is designed for Windows 10/11.
    echo Your current version is: %VERSION%
    echo Some features may not work correctly.
    echo.
    set /p "CONTINUE=Continue installation anyway? (y/N): "
    if /i not "!CONTINUE!"=="y" (
        echo Installation cancelled.
        exit /b 1
    )
)

:: Check available disk space (minimum 1GB)
echo Checking available disk space...
for /f "tokens=3" %%i in ('dir /-c %INSTALL_DIR% ^| find "bytes free"') do set "FREE_SPACE=%%i"
if defined FREE_SPACE (
    if %FREE_SPACE% lss 1073741824 (
        echo WARNING: Low disk space detected.
        echo At least 1GB is recommended for backups.
        echo Current free space: %FREE_SPACE% bytes
        echo.
    )
)

:: Install prerequisites
echo Installing prerequisites...
echo [%date% %time%] Installing prerequisites >> "%LOG_FILE%"

:: Check for PowerShell
powershell -command "Get-Host" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is required but not found.
    echo Please install PowerShell 5.0 or higher.
    exit /b 1
) else (
    echo ✓ PowerShell detected
)

:: Check for .NET Framework
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" /v Release >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: .NET Framework 4.7.2 or higher is recommended.
    echo Some features may not work without it.
) else (
    echo ✓ .NET Framework detected
)

:: Create desktop shortcut
echo Creating desktop shortcuts...
set "DESKTOP=%USERPROFILE%\Desktop"
if exist "%DESKTOP%" (
    echo @echo off > "%DESKTOP%\ReSet Toolkit.bat"
    echo cd /d "%INSTALL_DIR%" >> "%DESKTOP%\ReSet Toolkit.bat"
    echo call batch-reset.bat %%* >> "%DESKTOP%\ReSet Toolkit.bat"
    echo ✓ Desktop shortcut created
)

:: Create Start Menu entry
set "START_MENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
if exist "%START_MENU%" (
    if not exist "%START_MENU%\ReSet Toolkit" mkdir "%START_MENU%\ReSet Toolkit"
    
    echo @echo off > "%START_MENU%\ReSet Toolkit\ReSet Toolkit.bat"
    echo cd /d "%INSTALL_DIR%" >> "%START_MENU%\ReSet Toolkit\ReSet Toolkit.bat"
    echo call batch-reset.bat %%* >> "%START_MENU%\ReSet Toolkit\ReSet Toolkit.bat"
    
    echo @echo off > "%START_MENU%\ReSet Toolkit\Language Settings Reset.bat"
    echo cd /d "%SCRIPTS_DIR%" >> "%START_MENU%\ReSet Toolkit\Language Settings Reset.bat"
    echo call reset-language-settings.bat %%* >> "%START_MENU%\ReSet Toolkit\Language Settings Reset.bat"
    
    echo @echo off > "%START_MENU%\ReSet Toolkit\Display Settings Reset.bat"
    echo cd /d "%SCRIPTS_DIR%" >> "%START_MENU%\ReSet Toolkit\Display Settings Reset.bat"
    echo call reset-display.bat %%* >> "%START_MENU%\ReSet Toolkit\Display Settings Reset.bat"
    
    echo @echo off > "%START_MENU%\ReSet Toolkit\Network Reset.bat"
    echo cd /d "%SCRIPTS_DIR%" >> "%START_MENU%\ReSet Toolkit\Network Reset.bat"
    echo call reset-network.bat %%* >> "%START_MENU%\ReSet Toolkit\Network Reset.bat"
    
    echo ✓ Start Menu entries created
)

:: Set up environment variables
echo Setting up environment variables...
setx RESET_TOOLKIT_HOME "%INSTALL_DIR%" >nul 2>&1
setx PATH "%PATH%;%INSTALL_DIR%" >nul 2>&1
echo ✓ Environment variables configured

:: Create initial system restore point
echo Creating initial system restore point...
powershell -command "& {Checkpoint-Computer -Description 'ReSet Toolkit - Initial Installation' -RestorePointType 'APPLICATION_INSTALL'}" >nul 2>&1
if %errorlevel% equ 0 (
    echo ✓ System restore point created
) else (
    echo ⚠ Could not create system restore point
)

:: Initialize configuration file
echo Creating configuration file...
if not exist "%INSTALL_DIR%\config.ini" (
    call "%SCRIPTS_DIR%\config.bat" write >nul 2>&1
    if exist "%INSTALL_DIR%\config.ini" (
        echo ✓ Configuration file created
    ) else (
        echo ⚠ Could not create configuration file
    )
) else (
    echo ✓ Configuration file already exists
)

:: Create additional utility scripts shortcuts
echo Creating utility shortcuts...
if exist "%START_MENU%\ReSet Toolkit" (
    echo @echo off > "%START_MENU%\ReSet Toolkit\System Health Check.bat"
    echo cd /d "%INSTALL_DIR%" >> "%START_MENU%\ReSet Toolkit\System Health Check.bat"
    echo call health-check.bat %%* >> "%START_MENU%\ReSet Toolkit\System Health Check.bat"
    
    echo @echo off > "%START_MENU%\ReSet Toolkit\Cleanup Old Files.bat"
    echo cd /d "%INSTALL_DIR%" >> "%START_MENU%\ReSet Toolkit\Cleanup Old Files.bat"
    echo call cleanup.bat %%* >> "%START_MENU%\ReSet Toolkit\Cleanup Old Files.bat"
    
    echo @echo off > "%START_MENU%\ReSet Toolkit\Validate Installation.bat"
    echo cd /d "%INSTALL_DIR%" >> "%START_MENU%\ReSet Toolkit\Validate Installation.bat"
    echo call validate.bat %%* >> "%START_MENU%\ReSet Toolkit\Validate Installation.bat"
    
    echo ✓ Utility shortcuts created
)

:: Create uninstall script
echo Creating uninstall script...
echo @echo off > "%INSTALL_DIR%\uninstall.bat"
echo title ReSet Toolkit - Uninstall >> "%INSTALL_DIR%\uninstall.bat"
echo echo Uninstalling ReSet Toolkit... >> "%INSTALL_DIR%\uninstall.bat"
echo. >> "%INSTALL_DIR%\uninstall.bat"
echo :: Remove desktop shortcut >> "%INSTALL_DIR%\uninstall.bat"
echo if exist "%DESKTOP%\ReSet Toolkit.bat" del "%DESKTOP%\ReSet Toolkit.bat" >> "%INSTALL_DIR%\uninstall.bat"
echo. >> "%INSTALL_DIR%\uninstall.bat"
echo :: Remove Start Menu entries >> "%INSTALL_DIR%\uninstall.bat"
echo if exist "%START_MENU%\ReSet Toolkit" rd /s /q "%START_MENU%\ReSet Toolkit" >> "%INSTALL_DIR%\uninstall.bat"
echo. >> "%INSTALL_DIR%\uninstall.bat"
echo :: Remove environment variables >> "%INSTALL_DIR%\uninstall.bat"
echo reg delete "HKEY_CURRENT_USER\Environment" /v "RESET_TOOLKIT_HOME" /f ^>nul 2^>^&1 >> "%INSTALL_DIR%\uninstall.bat"
echo. >> "%INSTALL_DIR%\uninstall.bat"
echo echo ReSet Toolkit has been uninstalled. >> "%INSTALL_DIR%\uninstall.bat"
echo pause >> "%INSTALL_DIR%\uninstall.bat"

:: Validate installation
echo.
echo Validating installation...
set "VALIDATION_ERRORS=0"

if not exist "%SCRIPTS_DIR%\utils.bat" (
    echo ✗ Missing utilities script
    set /a VALIDATION_ERRORS+=1
) else (
    echo ✓ Utilities script found
)

if not exist "%INSTALL_DIR%\batch-reset.bat" (
    echo ✗ Missing main batch script
    set /a VALIDATION_ERRORS+=1
) else (
    echo ✓ Main batch script found
)

:: Count available reset scripts
set "SCRIPT_COUNT=0"
for %%f in ("%SCRIPTS_DIR%\reset-*.bat") do set /a SCRIPT_COUNT+=1

echo ✓ Found %SCRIPT_COUNT% reset scripts

if %VALIDATION_ERRORS% gtr 0 (
    echo.
    echo ⚠ Installation completed with %VALIDATION_ERRORS% warnings.
    echo Some features may not work correctly.
) else (
    echo.
    echo ✓ Installation completed successfully!
)

echo [%date% %time%] Installation completed with %VALIDATION_ERRORS% errors >> "%LOG_FILE%"

:: Show usage information
echo.
echo =============================================
echo  Installation Complete
echo =============================================
echo.
echo The ReSet Toolkit has been installed to:
echo %INSTALL_DIR%
echo.
echo Usage:
echo   • Run "batch-reset.bat" for the main interface
echo   • Run individual scripts from the scripts folder
echo   • Use desktop shortcut or Start Menu entries
echo.
echo Examples:
echo   batch-reset.bat --categories "display,audio"
echo   scripts\reset-language-settings.bat --silent
echo.
echo Documentation:
echo   See README.md for complete usage instructions
echo.
echo Support:
echo   Logs: %LOGS_DIR%
echo   Backups: %BACKUPS_DIR%
echo   Uninstall: run uninstall.bat
echo.

echo Installation log saved to: %LOG_FILE%
echo.

set /p "LAUNCH=Would you like to launch the ReSet Toolkit now? (y/N): "
if /i "%LAUNCH%"=="y" (
    call batch-reset.bat
)

echo.
echo Thank you for installing the ReSet Toolkit!
pause
exit /b 0