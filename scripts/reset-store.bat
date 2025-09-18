@echo off
:: Windows Settings Reset Toolkit - Windows Store Reset
:: Clears Microsoft Store cache and resets store preferences

title ReSet - Windows Store Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Windows Store Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset Windows Store cache and settings"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Store" "store_settings"

:: Close Windows Store
call :log_message "INFO" "Closing Windows Store..."
call :kill_process "WinStore.App.exe"
call :kill_process "Microsoft.WindowsStore_8wekyb3d8bbwe"
timeout /t 2 /nobreak >nul

:: Reset Windows Store cache
call :log_message "INFO" "Resetting Windows Store cache..."
wsreset.exe >nul 2>&1

:: Clear Store cache directories
call :clear_folder "%LOCALAPPDATA%\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache" "Store Cache"
call :clear_folder "%LOCALAPPDATA%\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\TempState" "Store Temp"

:: Reset Store preferences
call :log_message "INFO" "Resetting Store preferences..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Store\Configuration" /f >nul 2>&1

:: Clear Store licensing
powershell -command "Get-AppxPackage Microsoft.WindowsStore | Reset-AppxPackage" >nul 2>&1

call :log_message "SUCCESS" "Windows Store Reset completed"
echo.
echo Windows Store has been reset.
echo - Store cache cleared
echo - Store preferences reset
echo - Store licensing reset
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Windows Store Reset completed"
exit /b 0