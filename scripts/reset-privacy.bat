@echo off
:: Windows Settings Reset Toolkit - Privacy Settings Reset
:: Resets app permissions, location history, and telemetry settings

title ReSet - Privacy Settings Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Privacy Settings Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset privacy settings and app permissions"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager" "privacy_capabilities"
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "telemetry_settings"

:: Reset app permissions
call :log_message "INFO" "Resetting app permissions..."

:: Reset microphone access
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone" /v "Value" /t REG_SZ /d "Allow" /f >nul 2>&1

:: Reset camera access
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam" /v "Value" /t REG_SZ /d "Allow" /f >nul 2>&1

:: Reset location access
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v "Value" /t REG_SZ /d "Allow" /f >nul 2>&1

:: Clear location history
call :log_message "INFO" "Clearing location history..."
call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\LocationProvider" "Location History"

:: Reset telemetry to basic level
call :log_message "INFO" "Resetting telemetry settings..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d "1" /f >nul 2>&1

call :log_message "SUCCESS" "Privacy Settings Reset completed"
echo Privacy settings have been reset to defaults.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%

call :log_message "INFO" "Privacy Settings Reset completed"
exit /b 0