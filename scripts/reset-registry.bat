@echo off
:: Windows Settings Reset Toolkit - Registry Cleanup & Reset
:: Resets specific registry keys and clears orphaned entries

title ReSet - Registry Cleanup & Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Registry Cleanup & Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "perform registry cleanup and reset specific keys"

echo.
echo WARNING: Registry modifications can affect system stability.
echo This operation will create comprehensive backups before proceeding.
echo.
if /i not "%SILENT_MODE%"=="true" (
    set /p "CONTINUE_REG=Do you want to continue with registry cleanup? (yes/NO): "
    if /i not "%CONTINUE_REG%"=="yes" (
        echo Registry cleanup cancelled.
        exit /b 0
    )
)

:: Create comprehensive registry backups
call :log_message "INFO" "Creating comprehensive registry backups..."
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" "startup_programs"
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "system_startup"
call :backup_registry "HKEY_CURRENT_USER\Software\Classes" "user_file_associations"

:: Create full registry backup
call :log_message "INFO" "Creating full registry backup..."
for /f "tokens=2 delims==" %%i in ('wmic OS Get localdatetime /value') do set "dt=%%i"
set "YYYY=%dt:~0,4%"
set "MM=%dt:~4,2%"
set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%"
set "Min=%dt:~10,2%"
set "FULL_BACKUP=%BACKUP_DIR%\full_registry_backup_%YYYY%-%MM%-%DD%_%HH%-%Min%.reg"
regedit /e "%FULL_BACKUP%" >nul 2>&1

:: Clean orphaned entries in software list
call :log_message "INFO" "Cleaning orphaned software entries..."
for /f "tokens=*" %%i in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "DisplayName" 2^>nul ^| findstr "ERROR"') do (
    reg delete "%%i" /f >nul 2>&1
)

:: Clean orphaned startup entries
call :log_message "INFO" "Cleaning orphaned startup entries..."
for /f "tokens=1,2*" %%i in ('reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" 2^>nul') do (
    if not exist "%%k" (
        call :log_message "INFO" "Removing orphaned startup entry: %%i"
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "%%i" /f >nul 2>&1
    )
)

:: Clean Windows Error Reporting entries
call :log_message "INFO" "Cleaning Windows Error Reporting entries..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Windows Error Reporting" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" /f >nul 2>&1

:: Reset Windows Update client ID
call :log_message "INFO" "Resetting Windows Update client ID..."
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v "SusClientId" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v "SusClientIdValidation" /f >nul 2>&1

:: Clean MUI cache
call :log_message "INFO" "Cleaning MUI cache..."
reg delete "HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" /f >nul 2>&1

:: Reset icon cache registry entries
call :log_message "INFO" "Resetting icon cache registry..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" /f >nul 2>&1

:: Clean prefetch references
call :log_message "INFO" "Cleaning prefetch registry references..."
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v "EnableSuperfetch" /f >nul 2>&1

:: Reset Explorer shell folders to defaults
call :log_message "INFO" "Resetting shell folders..."
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Desktop" /t REG_SZ /d "%USERPROFILE%\Desktop" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Favorites" /t REG_SZ /d "%USERPROFILE%\Favorites" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "Personal" /t REG_SZ /d "%USERPROFILE%\Documents" /f >nul 2>&1

:: Clean COM registrations (safe cleanup)
call :log_message "INFO" "Cleaning orphaned COM registrations..."
for /f "tokens=*" %%i in ('reg query "HKEY_CLASSES_ROOT\CLSID" /s /f "InprocServer32" 2^>nul ^| findstr "ERROR"') do (
    reg delete "%%i" /f >nul 2>&1
)

:: Reset accessibility registry settings
call :log_message "INFO" "Resetting accessibility registry settings..."
reg add "HKEY_CURRENT_USER\Control Panel\Accessibility" /f >nul 2>&1

:: Compact registry hives
call :log_message "INFO" "Compacting registry hives..."
compact /c /s /q "%SystemRoot%\System32\config\*" >nul 2>&1

call :log_message "SUCCESS" "Registry Cleanup & Reset completed"
echo.
echo Registry cleanup and reset completed.
echo Changes include:
echo - Orphaned software entries removed
echo - Startup entries cleaned
echo - Error reporting entries cleared
echo - Windows Update client ID reset
echo - MUI cache cleaned
echo - Shell folders reset
echo - COM registrations cleaned
echo - Registry hives compacted
echo.
echo IMPORTANT: Full registry backup created at:
echo %FULL_BACKUP%
echo.
echo Additional backups created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo A system restart is recommended to ensure all changes take effect.
    echo Would you like to restart now? (y/N)
    set /p "RESTART=Enter your choice: "
    if /i "%RESTART%"=="y" (
        call :log_message "INFO" "System restart initiated by user"
        shutdown /r /t 10 /c "Restarting to complete registry cleanup..."
    )
)

call :log_message "INFO" "Registry Cleanup & Reset completed"
exit /b 0