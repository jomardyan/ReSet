@echo off
:: Windows Settings Reset Toolkit - System Environment Reset
:: Resets environment variables and system paths

title ReSet - System Environment Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting System Environment Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset system environment variables and PATH"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "system_environment"
call :backup_registry "HKEY_CURRENT_USER\Environment" "user_environment"

:: Reset system PATH to default
call :log_message "INFO" "Resetting system PATH..."
set "DEFAULT_PATH=%SystemRoot%\system32;%SystemRoot%;%SystemRoot%\System32\Wbem;%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\;%SYSTEMROOT%\System32\OpenSSH\"
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "PATH" /t REG_EXPAND_SZ /d "%DEFAULT_PATH%" /f >nul 2>&1

:: Reset common system environment variables
call :log_message "INFO" "Resetting system environment variables..."
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "PATHEXT" /t REG_SZ /d ".COM;.EXE;.BAT;.CMD;.VBS;.VBE;.JS;.JSE;.WSF;.WSH;.MSC" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "PROCESSOR_ARCHITECTURE" /t REG_SZ /d "AMD64" /f >nul 2>&1

:: Clear custom user environment variables (with confirmation)
if /i not "%SILENT_MODE%"=="true" (
    echo.
    echo WARNING: This will remove custom user environment variables.
    set /p "CLEAR_USER_ENV=Clear custom user environment variables? (y/N): "
    if /i "%CLEAR_USER_ENV%"=="y" (
        call :log_message "INFO" "Clearing user environment variables..."
        reg delete "HKEY_CURRENT_USER\Environment" /v "PATH" /f >nul 2>&1
        :: Keep essential user variables
        for /f "tokens=1,2*" %%i in ('reg query "HKEY_CURRENT_USER\Environment" 2^>nul ^| findstr /v "TEMP\|TMP\|OneDrive"') do (
            if not "%%i"=="HKEY_CURRENT_USER\Environment" (
                reg delete "HKEY_CURRENT_USER\Environment" /v "%%i" /f >nul 2>&1
            )
        )
    )
)

:: Reset TEMP and TMP variables
call :log_message "INFO" "Resetting TEMP and TMP variables..."
reg add "HKEY_CURRENT_USER\Environment" /v "TEMP" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\AppData\Local\Temp" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Environment" /v "TMP" /t REG_EXPAND_SZ /d "%%USERPROFILE%%\AppData\Local\Temp" /f >nul 2>&1

:: Reset Windows system variables
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "OS" /t REG_SZ /d "Windows_NT" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "ComSpec" /t REG_EXPAND_SZ /d "%%SystemRoot%%\system32\cmd.exe" /f >nul 2>&1

:: Refresh environment variables
call :log_message "INFO" "Refreshing environment variables..."
rundll32.exe user32.dll,UpdatePerUserSystemParameters 1, True >nul 2>&1

call :log_message "SUCCESS" "System Environment Reset completed"
echo.
echo System environment has been reset to defaults.
echo - System PATH reset to default
echo - PATHEXT reset to standard extensions
echo - TEMP/TMP variables reset
echo - Custom user variables cleared (if confirmed)
echo.
echo Changes will take effect for new processes and sessions.
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo Would you like to restart now to ensure all changes take effect? (y/N)
    set /p "RESTART=Enter your choice: "
    if /i "%RESTART%"=="y" (
        call :log_message "INFO" "System restart initiated by user"
        shutdown /r /t 10 /c "Restarting to complete environment reset..."
    )
)

call :log_message "INFO" "System Environment Reset completed"
exit /b 0