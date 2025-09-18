@echo off
:: Windows Settings Reset Toolkit - User Account Control Reset
:: Resets UAC to default level and restores admin approval mode

title ReSet - User Account Control Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting User Account Control Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset User Account Control (UAC) settings to defaults"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "uac_policies"

:: Reset UAC to default level (level 2 - notify when apps try to make changes)
call :log_message "INFO" "Resetting UAC to default level..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d "5" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorUser" /t REG_DWORD /d "3" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset UAC registry keys to default
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableVirtualization" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableInstallerDetection" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "ValidateAdminCodeSignatures" /t REG_DWORD /d "0" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableSecureUIAPaths" /t REG_DWORD /d "1" /f >nul 2>&1

:: Clear any custom UAC policy overrides
call :log_message "INFO" "Clearing custom UAC policy overrides..."
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "FilterAdministratorToken" /f >nul 2>&1

call :log_message "SUCCESS" "User Account Control Reset completed"
echo.
echo User Account Control has been reset to defaults.
echo - UAC level: Notify when apps try to make changes (default)
echo - Admin approval mode enabled
echo - Secure desktop prompts enabled
echo - Installer detection enabled
echo.
echo A system restart may be required for changes to take full effect.
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo Would you like to restart now to complete the UAC reset? (y/N)
    set /p "RESTART=Enter your choice: "
    if /i "%RESTART%"=="y" (
        call :log_message "INFO" "System restart initiated by user"
        shutdown /r /t 10 /c "Restarting to complete UAC reset..."
    )
)

call :log_message "INFO" "User Account Control Reset completed"
exit /b 0