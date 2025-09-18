@echo off
:: Windows Settings Reset Toolkit - Backup Restore Utility
:: Restores system settings from previously created backups

title ReSet - Backup Restore Utility

setlocal enabledelayedexpansion

:: Initialize
call "%~dp0scripts\utils.bat" %*
if errorlevel 1 exit /b 1

set "BACKUP_DIR=%~dp0backups"
set "RESTORE_DATE="
set "RESTORE_CATEGORY="
set "LIST_BACKUPS=false"
set "RESTORE_ALL=false"

echo.
echo ============================================
echo  ReSet Toolkit - Backup Restore Utility
echo ============================================
echo.

:: Parse command line arguments
:parse_args
if "%~1"=="" goto :args_parsed
if /i "%~1"=="--date" (
    set "RESTORE_DATE=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--category" (
    set "RESTORE_CATEGORY=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--list" (
    set "LIST_BACKUPS=true"
    shift
    goto :parse_args
)
if /i "%~1"=="--restore-all" (
    set "RESTORE_ALL=true"
    shift
    goto :parse_args
)
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/?" goto :show_help
shift
goto :parse_args

:args_parsed

call :log_message "INFO" "Starting Backup Restore Utility"

:: List backups if requested
if /i "%LIST_BACKUPS%"=="true" (
    call :list_available_backups
    goto :end
)

:: Show help if no arguments
if "%RESTORE_DATE%"=="" if "%RESTORE_ALL%"=="false" (
    call :show_interactive_menu
    goto :end
)

:: Restore specific backup
if not "%RESTORE_DATE%"=="" (
    call :restore_from_date "%RESTORE_DATE%" "%RESTORE_CATEGORY%"
)

:: Restore all from date
if /i "%RESTORE_ALL%"=="true" (
    if "%RESTORE_DATE%"=="" (
        echo ERROR: --restore-all requires --date parameter
        exit /b 1
    )
    call :restore_all_from_date "%RESTORE_DATE%"
)

goto :end

:show_help
echo Usage: restore-backup.bat [OPTIONS]
echo.
echo Options:
echo   --date DATE           Restore backups from specific date (YYYY-MM-DD)
echo   --category CATEGORY   Restore specific category backup
echo   --list               List all available backups
echo   --restore-all        Restore all backups from specified date
echo   --help               Show this help message
echo.
echo Examples:
echo   restore-backup.bat --list
echo   restore-backup.bat --date "2024-01-15" --category "display"
echo   restore-backup.bat --restore-all --date "2024-01-15"
echo.
goto :end

:show_interactive_menu
echo Available backup restoration options:
echo.
echo 1. List all available backups
echo 2. Restore specific backup by date and category
echo 3. Restore all backups from a specific date
echo 4. Exit
echo.
set /p "CHOICE=Enter your choice (1-4): "

if "%CHOICE%"=="1" call :list_available_backups && goto :show_interactive_menu
if "%CHOICE%"=="2" call :interactive_specific_restore && goto :end
if "%CHOICE%"=="3" call :interactive_restore_all && goto :end
if "%CHOICE%"=="4" goto :end

echo Invalid choice. Please try again.
goto :show_interactive_menu

:list_available_backups
echo.
echo Available backups in %BACKUP_DIR%:
echo ======================================
echo.

if not exist "%BACKUP_DIR%\*" (
    echo No backups found.
    goto :eof
)

:: Group backups by date
set "CURRENT_DATE="
for /f "tokens=*" %%f in ('dir /b /ad "%BACKUP_DIR%" 2^>nul ^| sort') do (
    set "BACKUP_NAME=%%f"
    
    :: Extract date from backup name
    for /f "tokens=2 delims=_" %%d in ("!BACKUP_NAME!") do (
        set "BACKUP_DATE=%%d"
        if not "!BACKUP_DATE!"=="!CURRENT_DATE!" (
            echo.
            echo Date: !BACKUP_DATE!
            echo ----------------
            set "CURRENT_DATE=!BACKUP_DATE!"
        )
        
        :: Extract category from backup name
        for /f "tokens=1 delims=_" %%c in ("!BACKUP_NAME!") do (
            echo   - %%c
        )
    )
)

:: List registry backups
echo.
echo Registry Backups:
echo ----------------
for /f "tokens=*" %%f in ('dir /b "%BACKUP_DIR%\*.reg" 2^>nul ^| sort') do (
    echo   - %%f
)

echo.
goto :eof

:interactive_specific_restore
echo.
echo Enter backup details to restore:
echo.
set /p "INPUT_DATE=Enter backup date (YYYY-MM-DD): "
set /p "INPUT_CATEGORY=Enter category (or leave blank for all): "

if "%INPUT_DATE%"=="" (
    echo ERROR: Date is required.
    goto :eof
)

call :restore_from_date "%INPUT_DATE%" "%INPUT_CATEGORY%"
goto :eof

:interactive_restore_all
echo.
echo WARNING: This will restore ALL backups from a specific date.
echo This will overwrite current settings with backup data.
echo.
set /p "INPUT_DATE=Enter backup date (YYYY-MM-DD): "
if "%INPUT_DATE%"=="" (
    echo ERROR: Date is required.
    goto :eof
)

echo.
echo This will restore ALL settings from %INPUT_DATE%
set /p "CONFIRM=Are you sure you want to continue? (yes/NO): "
if /i not "%CONFIRM%"=="yes" (
    echo Operation cancelled.
    goto :eof
)

call :restore_all_from_date "%INPUT_DATE%"
goto :eof

:restore_from_date
set "TARGET_DATE=%~1"
set "TARGET_CATEGORY=%~2"

call :log_message "INFO" "Restoring backup from date: %TARGET_DATE%, category: %TARGET_CATEGORY%"

if "%TARGET_CATEGORY%"=="" (
    echo Restoring all backups from %TARGET_DATE%...
    call :restore_all_from_date "%TARGET_DATE%"
    goto :eof
)

:: Find matching backup
set "BACKUP_FOUND=false"
for /f "tokens=*" %%f in ('dir /b /ad "%BACKUP_DIR%" 2^>nul') do (
    set "BACKUP_NAME=%%f"
    echo !BACKUP_NAME! | findstr /i "%TARGET_CATEGORY%_%TARGET_DATE%" >nul
    if !errorlevel! equ 0 (
        set "BACKUP_FOUND=true"
        call :restore_backup "!BACKUP_NAME!"
    )
)

:: Check for registry backups
for /f "tokens=*" %%f in ('dir /b "%BACKUP_DIR%\*.reg" 2^>nul') do (
    set "REG_BACKUP=%%f"
    echo !REG_BACKUP! | findstr /i "%TARGET_CATEGORY%" >nul
    if !errorlevel! equ 0 (
        echo !REG_BACKUP! | findstr "%TARGET_DATE%" >nul
        if !errorlevel! equ 0 (
            set "BACKUP_FOUND=true"
            call :restore_registry_backup "!REG_BACKUP!"
        )
    )
)

if /i "%BACKUP_FOUND%"=="false" (
    echo ERROR: No backup found for category '%TARGET_CATEGORY%' on date '%TARGET_DATE%'
    call :log_message "ERROR" "No backup found for category '%TARGET_CATEGORY%' on date '%TARGET_DATE%'"
    exit /b 1
)

goto :eof

:restore_all_from_date
set "TARGET_DATE=%~1"

call :log_message "INFO" "Restoring all backups from date: %TARGET_DATE%"
echo Restoring all backups from %TARGET_DATE%...
echo.

set "BACKUPS_RESTORED=0"

:: Restore folder backups
for /f "tokens=*" %%f in ('dir /b /ad "%BACKUP_DIR%" 2^>nul') do (
    set "BACKUP_NAME=%%f"
    echo !BACKUP_NAME! | findstr "%TARGET_DATE%" >nul
    if !errorlevel! equ 0 (
        call :restore_backup "!BACKUP_NAME!"
        set /a BACKUPS_RESTORED+=1
    )
)

:: Restore registry backups
for /f "tokens=*" %%f in ('dir /b "%BACKUP_DIR%\*.reg" 2^>nul') do (
    set "REG_BACKUP=%%f"
    echo !REG_BACKUP! | findstr "%TARGET_DATE%" >nul
    if !errorlevel! equ 0 (
        call :restore_registry_backup "!REG_BACKUP!"
        set /a BACKUPS_RESTORED+=1
    )
)

if %BACKUPS_RESTORED% equ 0 (
    echo ERROR: No backups found for date '%TARGET_DATE%'
    call :log_message "ERROR" "No backups found for date '%TARGET_DATE%'"
    exit /b 1
) else (
    echo.
    echo Successfully restored %BACKUPS_RESTORED% backups from %TARGET_DATE%
    call :log_message "SUCCESS" "Restored %BACKUPS_RESTORED% backups from %TARGET_DATE%"
)

goto :eof

:restore_backup
set "BACKUP_NAME=%~1"
set "BACKUP_PATH=%BACKUP_DIR%\%BACKUP_NAME%"

if not exist "%BACKUP_PATH%" (
    call :log_message "ERROR" "Backup path does not exist: %BACKUP_PATH%"
    goto :eof
)

call :log_message "INFO" "Restoring backup: %BACKUP_NAME%"
echo Restoring: %BACKUP_NAME%

:: Determine restore destination based on backup name
set "RESTORE_DEST="

if "%BACKUP_NAME:~0,12%"=="international_" set "RESTORE_DEST=%USERPROFILE%"
if "%BACKUP_NAME:~0,8%"=="desktop_" set "RESTORE_DEST=%USERPROFILE%"
if "%BACKUP_NAME:~0,6%"=="theme_" set "RESTORE_DEST=%USERPROFILE%"

if "%RESTORE_DEST%"=="" (
    call :log_message "WARN" "Could not determine restore destination for: %BACKUP_NAME%"
    goto :eof
)

:: Copy backup files back to original location
xcopy "%BACKUP_PATH%\*" "%RESTORE_DEST%\" /e /i /y /q >nul 2>&1

if %errorlevel% equ 0 (
    call :log_message "SUCCESS" "Backup restored successfully: %BACKUP_NAME%"
    echo ✓ %BACKUP_NAME% restored
) else (
    call :log_message "ERROR" "Failed to restore backup: %BACKUP_NAME%"
    echo ✗ Failed to restore %BACKUP_NAME%
)

goto :eof

:restore_registry_backup
set "REG_BACKUP=%~1"
set "REG_PATH=%BACKUP_DIR%\%REG_BACKUP%"

call :log_message "INFO" "Restoring registry backup: %REG_BACKUP%"
echo Restoring registry: %REG_BACKUP%

reg import "%REG_PATH%" >nul 2>&1

if %errorlevel% equ 0 (
    call :log_message "SUCCESS" "Registry backup restored: %REG_BACKUP%"
    echo ✓ %REG_BACKUP% restored
) else (
    call :log_message "ERROR" "Failed to restore registry backup: %REG_BACKUP%"
    echo ✗ Failed to restore %REG_BACKUP%
)

goto :eof

:end
echo.
if defined BACKUPS_RESTORED if %BACKUPS_RESTORED% gtr 0 (
    echo ==========================================
    echo Backup restoration completed successfully
    echo ==========================================
    echo.
    echo IMPORTANT: Some changes may require:
    echo - Signing out and signing back in
    echo - Restarting Windows Explorer
    echo - Restarting the computer
    echo.
    echo Log file: %LOG_FILE%
    echo.
    
    if /i not "%SILENT_MODE%"=="true" (
        echo Would you like to restart Explorer now? (y/N)
        set /p "RESTART_EXPLORER=Enter your choice: "
        if /i "!RESTART_EXPLORER!"=="y" (
            call :log_message "INFO" "Restarting Explorer as requested"
            taskkill /f /im explorer.exe >nul 2>&1
            timeout /t 2 /nobreak >nul
            start explorer.exe
        )
    )
)

call :log_message "INFO" "Backup Restore Utility completed"
pause
exit /b 0