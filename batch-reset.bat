@echo off
:: Windows Settings Reset Toolkit - Batch Reset Script
:: Main script for running multiple reset operations

title ReSet - Batch Reset Toolkit

setlocal enabledelayedexpansion

:: Initialize variables
set "SCRIPT_DIR=%~dp0scripts"
set "CATEGORIES="
set "SELECTED_SCRIPTS="
set "CREATE_RESTORE_POINT=false"
set "SILENT_MODE=false"
set "BACKUP_PATH="

:: Parse command line arguments
:parse_args
if "%~1"=="" goto :args_parsed
if /i "%~1"=="--categories" (
    set "CATEGORIES=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--scripts" (
    set "SELECTED_SCRIPTS=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--create-restore-point" (
    set "CREATE_RESTORE_POINT=true"
    shift
    goto :parse_args
)
if /i "%~1"=="--silent" (
    set "SILENT_MODE=true"
    shift
    goto :parse_args
)
if /i "%~1"=="--backup-path" (
    set "BACKUP_PATH=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/?" goto :show_help
if /i "%~1"=="-h" goto :show_help
shift
goto :parse_args

:args_parsed

:: Initialize utility functions
call "%SCRIPT_DIR%\utils.bat"
if errorlevel 1 (
    echo [91mERROR: Could not initialize utility functions[0m
    exit /b 1
)

:: Load configuration
call "%SCRIPT_DIR%\config.bat" read >nul 2>&1

echo.
echo [96m============================================[0m
echo [96m  Windows Settings Reset Toolkit (ReSet)[0m
echo [96m============================================[0m
echo.

call :log_message "INFO" "Starting Batch Reset operation"

:: Show available categories if none specified
if "%CATEGORIES%"=="" if "%SELECTED_SCRIPTS%"=="" (
    call :show_menu
    goto :end
)

:: Create system restore point if requested
if /i "%CREATE_RESTORE_POINT%"=="true" (
    call :create_restore_point
)

:: Process categories
if not "%CATEGORIES%"=="" (
    call :process_categories "%CATEGORIES%"
)

:: Process individual scripts
if not "%SELECTED_SCRIPTS%"=="" (
    call :process_scripts "%SELECTED_SCRIPTS%"
)

call :log_message "SUCCESS" "Batch Reset operation completed"
echo.
echo Batch reset operation completed successfully.
echo Check the log file for detailed information: %LOG_FILE%
echo.
goto :end

:show_help
echo Usage: batch-reset.bat [OPTIONS]
echo.
echo Options:
echo   --categories CATS        Run scripts by category (comma-separated)
echo   --scripts SCRIPTS        Run specific scripts (comma-separated)
echo   --create-restore-point   Create system restore point before reset
echo   --silent                 Run without user prompts
echo   --backup-path PATH       Custom backup location
echo   --help                   Show this help message
echo.
echo Available Categories:
echo   language      - Language and regional settings
echo   display       - Display and visual settings
echo   audio         - Audio and sound settings
echo   network       - Network and connectivity
echo   security      - Security and privacy settings
echo   search        - Search and indexing
echo   interface     - Start menu, taskbar, and shell
echo   files         - File associations and management
echo   performance   - Power and performance settings
echo   apps          - Applications and Windows Store
echo   input         - Mouse, keyboard, and accessibility
echo   system        - System components and environment
echo   all           - All available reset scripts
echo.
echo Examples:
echo   batch-reset.bat --categories "display,audio"
echo   batch-reset.bat --scripts "language-settings,network"
echo   batch-reset.bat --categories "all" --create-restore-point --silent
echo.
goto :end

:show_menu
echo Available Reset Categories:
echo.
echo  1. Language ^& Regional Settings
echo  2. Display Settings
echo  3. Audio Settings  
echo  4. Network ^& Connectivity
echo  5. Security ^& Privacy
echo  6. Search ^& Indexing
echo  7. Interface (Start Menu, Taskbar)
echo  8. File Management
echo  9. Performance ^& Power
echo 10. Applications ^& Store
echo 11. Input Devices ^& Accessibility
echo 12. System Components
echo 13. All Categories
echo.
echo  0. Exit
echo.
set /p "CHOICE=Enter your choice (0-13): "

if "%CHOICE%"=="0" goto :end
if "%CHOICE%"=="1" call :run_single_script "reset-language-settings.bat"
if "%CHOICE%"=="2" call :run_single_script "reset-display.bat"
if "%CHOICE%"=="3" call :run_single_script "reset-audio.bat"
if "%CHOICE%"=="4" set "CATEGORIES=network" && call :process_categories "network"
if "%CHOICE%"=="5" set "CATEGORIES=security" && call :process_categories "security"
if "%CHOICE%"=="6" call :run_single_script "reset-search.bat"
if "%CHOICE%"=="7" set "CATEGORIES=interface" && call :process_categories "interface"
if "%CHOICE%"=="8" set "CATEGORIES=files" && call :process_categories "files"
if "%CHOICE%"=="9" set "CATEGORIES=performance" && call :process_categories "performance"
if "%CHOICE%"=="10" set "CATEGORIES=apps" && call :process_categories "apps"
if "%CHOICE%"=="11" call :run_single_script "reset-input-devices.bat"
if "%CHOICE%"=="12" set "CATEGORIES=system" && call :process_categories "system"
if "%CHOICE%"=="13" set "CATEGORIES=all" && call :process_categories "all"

goto :end

:process_categories
set "CATS=%~1"

for %%i in (%CATS%) do (
    set "CAT=%%i"
    call :run_category_scripts "!CAT!"
)
goto :eof

:run_category_scripts
set "CATEGORY=%~1"

echo.
echo Running %CATEGORY% category reset scripts...
echo.

if /i "%CATEGORY%"=="language" (
    call :run_single_script "reset-language-settings.ps1"
    call :run_single_script "reset-datetime.ps1"
)

if /i "%CATEGORY%"=="display" (
    call :run_single_script "reset-display.ps1"
    call :run_single_script "reset-fonts.ps1"
)

if /i "%CATEGORY%"=="audio" (
    call :run_single_script "reset-audio.ps1"
)

if /i "%CATEGORY%"=="network" (
    call :run_single_script "reset-network.ps1"
    call :run_single_script "reset-windows-update.ps1"
)

if /i "%CATEGORY%"=="security" (
    call :run_single_script "reset-uac.ps1"
    call :run_single_script "reset-privacy.ps1"
    call :run_single_script "reset-defender.ps1"
)

if /i "%CATEGORY%"=="search" (
    call :run_single_script "reset-search.ps1"
)

if /i "%CATEGORY%"=="interface" (
    call :run_single_script "reset-startmenu.ps1"
    call :run_single_script "reset-shell.ps1"
)

if /i "%CATEGORY%"=="files" (
    call :run_single_script "reset-file-associations.ps1"
)

if /i "%CATEGORY%"=="performance" (
    call :run_single_script "reset-power.ps1"
    call :run_single_script "reset-performance.ps1"
)

if /i "%CATEGORY%"=="apps" (
    call :run_single_script "reset-browser.ps1"
    call :run_single_script "reset-store.ps1"
)

if /i "%CATEGORY%"=="input" (
    call :run_single_script "reset-input-devices.ps1"
)

if /i "%CATEGORY%"=="system" (
    call :run_single_script "reset-features.ps1"
    call :run_single_script "reset-environment.ps1"
    call :run_single_script "reset-registry.ps1"
)

if /i "%CATEGORY%"=="all" (
    call :run_all_scripts
)

goto :eof

:process_scripts
set "SCRIPTS=%~1"

for %%i in (%SCRIPTS%) do (
    set "SCRIPT=%%i"
    call :run_single_script "reset-!SCRIPT!.ps1"
)
goto :eof

:run_single_script
set "SCRIPT_NAME=%~1"
set "SCRIPT_PATH=%SCRIPT_DIR%\%SCRIPT_NAME%"

if not exist "%SCRIPT_PATH%" (
    call :log_message "ERROR" "Script not found: %SCRIPT_NAME%"
    echo ERROR: Script not found: %SCRIPT_NAME%
    goto :eof
)

call :log_message "INFO" "Running script: %SCRIPT_NAME%"
echo.
echo ----------------------------------------
echo Running: %SCRIPT_NAME%
echo ----------------------------------------

:: Check if it's a PowerShell script
echo "%SCRIPT_NAME%" | findstr /i "\.ps1$" >nul
if %errorlevel% == 0 (
    :: Run PowerShell script
    if /i "%SILENT_MODE%"=="true" (
        powershell -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -Silent
    ) else (
        powershell -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"
    )
) else (
    :: Run batch script (legacy support)
    if /i "%SILENT_MODE%"=="true" (
        call "%SCRIPT_PATH%" --silent
    ) else (
        call "%SCRIPT_PATH%"
    )
)

set "SCRIPT_EXIT_CODE=%errorlevel%"

if %SCRIPT_EXIT_CODE% == 0 (
    call :log_message "SUCCESS" "Script completed successfully: %SCRIPT_NAME%"
    echo %SCRIPT_NAME% completed successfully.
) else (
    call :log_message "ERROR" "Script failed with exit code %SCRIPT_EXIT_CODE%: %SCRIPT_NAME%"
    echo ERROR: %SCRIPT_NAME% failed with exit code %SCRIPT_EXIT_CODE%
    
    if /i not "%SILENT_MODE%"=="true" (
        echo.
        set /p "CONTINUE=Continue with remaining scripts? (y/N): "
        if /i not "!CONTINUE!"=="y" (
            echo Batch operation cancelled by user.
            exit /b 1
        )
    )
)

echo.
timeout /t 2 /nobreak >nul
goto :eof

:run_all_scripts
echo.
echo Running ALL reset scripts...
echo This will reset ALL Windows settings to defaults.
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo WARNING: This operation will reset ALL system settings!
    echo This cannot be easily undone without backups.
    echo.
    set /p "CONFIRM_ALL=Are you absolutely sure you want to continue? (yes/NO): "
    if /i not "!CONFIRM_ALL!"=="yes" (
        echo Operation cancelled.
        goto :eof
    )
)

:: Language & Regional
call :run_single_script "reset-language-settings.ps1"
call :run_single_script "reset-datetime.ps1"

:: Display & Audio
call :run_single_script "reset-display.ps1"
call :run_single_script "reset-audio.ps1"
call :run_single_script "reset-fonts.ps1"

:: Network & Connectivity
call :run_single_script "reset-network.ps1"
call :run_single_script "reset-windows-update.ps1"

:: Security & Privacy
call :run_single_script "reset-uac.ps1"
call :run_single_script "reset-privacy.ps1"
call :run_single_script "reset-defender.ps1"

:: Search & Interface
call :run_single_script "reset-search.ps1"
call :run_single_script "reset-startmenu.ps1"
call :run_single_script "reset-shell.ps1"

:: File Management
call :run_single_script "reset-file-associations.ps1"

:: Performance & Power
call :run_single_script "reset-power.ps1"
call :run_single_script "reset-performance.ps1"

:: Applications & Store
call :run_single_script "reset-browser.ps1"
call :run_single_script "reset-store.ps1"

:: Input & Accessibility
call :run_single_script "reset-input-devices.ps1"

:: System Components
call :run_single_script "reset-features.ps1"
call :run_single_script "reset-environment.ps1"
call :run_single_script "reset-registry.ps1"

echo.
echo ==========================================
echo ALL RESET SCRIPTS COMPLETED
echo ==========================================
echo.
echo IMPORTANT: A system restart is recommended
echo to ensure all changes take full effect.
echo.

goto :eof

:create_restore_point
call :log_message "INFO" "Creating system restore point..."
echo Creating system restore point...

powershell -command "& {Checkpoint-Computer -Description 'ReSet Toolkit - Before Reset' -RestorePointType 'MODIFY_SETTINGS'}" >nul 2>&1

if %errorlevel% == 0 (
    call :log_message "SUCCESS" "System restore point created"
    echo System restore point created successfully.
) else (
    call :log_message "WARN" "Failed to create system restore point"
    echo WARNING: Could not create system restore point.
    echo Continue anyway? (y/N)
    if /i not "%SILENT_MODE%"=="true" (
        set /p "CONTINUE_NO_RP="
        if /i not "!CONTINUE_NO_RP!"=="y" (
            echo Operation cancelled.
            exit /b 1
        )
    )
)
echo.
goto :eof

:end
echo.
echo Batch reset operation finished.
echo.
pause
exit /b 0