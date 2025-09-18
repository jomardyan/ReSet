@echo off
:: Windows Settings Reset Toolkit - Performance Counters Reset
:: Rebuilds performance counter registry and resets system monitoring

title ReSet - Performance Counters Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Performance Counters Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "rebuild performance counters and reset monitoring"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Perflib" "performance_counters"

:: Stop performance monitoring services
call :log_message "INFO" "Stopping performance monitoring services..."
net stop "Performance Logs and Alerts" >nul 2>&1
net stop "Windows Management Instrumentation" >nul 2>&1

:: Rebuild performance counters
call :log_message "INFO" "Rebuilding performance counters..."
lodctr /r >nul 2>&1

if %errorlevel% == 0 (
    call :log_message "SUCCESS" "Performance counters rebuilt successfully"
) else (
    call :log_message "ERROR" "Failed to rebuild performance counters"
)

:: Reset WMI repository
call :log_message "INFO" "Resetting WMI repository..."
winmgmt /resetrepository >nul 2>&1

:: Start services
call :log_message "INFO" "Starting performance monitoring services..."
net start "Windows Management Instrumentation" >nul 2>&1
net start "Performance Logs and Alerts" >nul 2>&1

call :log_message "SUCCESS" "Performance Counters Reset completed"
echo.
echo Performance counters have been rebuilt.
echo - Performance counter registry rebuilt
echo - WMI repository reset
echo - Monitoring services restarted
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Performance Counters Reset completed"
exit /b 0