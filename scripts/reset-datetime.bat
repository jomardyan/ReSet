@echo off
:: Windows Settings Reset Toolkit - Date Time Settings Reset
:: Resets time zone, time servers, and date/time display formats

title ReSet - Date Time Settings Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Date Time Settings Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset date, time, and time zone settings to defaults"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "timezone_settings"
call :backup_registry "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time" "time_service"

:: Reset time zone to automatic detection
call :log_message "INFO" "Enabling automatic time zone detection..."
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\tzautoupdate" /v "Start" /t REG_DWORD /d "3" /f >nul 2>&1

:: Reset time synchronization
call :log_message "INFO" "Resetting time synchronization..."
w32tm /config /manualpeerlist:"time.windows.com,0x1" /syncfromflags:manual /reliable:YES /update >nul 2>&1
w32tm /resync /force >nul 2>&1

:: Reset date and time formats (handled by language settings, but ensure consistency)
call :log_message "INFO" "Ensuring date/time format consistency..."
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sShortDate" /t REG_SZ /d "M/d/yyyy" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sTimeFormat" /t REG_SZ /d "h:mm:ss tt" /f >nul 2>&1

:: Reset time zone display
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Time Zones" /f >nul 2>&1

:: Restart time service
call :restart_service "w32time"

call :log_message "SUCCESS" "Date Time Settings Reset completed"
echo.
echo Date and time settings have been reset to defaults.
echo - Automatic time zone detection enabled
echo - Time synchronization reset to Windows time servers
echo - Date/time formats reset to US standard
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Date Time Settings Reset completed"
exit /b 0