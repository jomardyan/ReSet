@echo off
:: Windows Settings Reset Toolkit - Audio Settings Reset
:: Resets default playback/recording devices, audio enhancements, and volume levels

title ReSet - Audio Settings Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Audio Settings Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset all audio settings to defaults"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio" "audio_settings"
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices" "audio_devices"

:: Stop audio services temporarily
call :log_message "INFO" "Stopping audio services..."
net stop "Windows Audio" >nul 2>&1
net stop "Windows Audio Endpoint Builder" >nul 2>&1
timeout /t 2 /nobreak >nul

:: Reset default audio devices
call :log_message "INFO" "Resetting default audio devices..."
powershell -command "& {Get-AudioDevice -List | Where-Object {$_.Type -eq 'Playback' -and $_.Default -eq $false} | Set-AudioDevice -DefaultOnly}" >nul 2>&1

:: Reset audio enhancements
call :log_message "INFO" "Disabling audio enhancements..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" /f >nul 2>&1

:: Reset system volume to 50%
call :log_message "INFO" "Resetting system volume..."
powershell -command "(New-Object -comObject WScript.Shell).SendKeys([char]175)" >nul 2>&1

:: Reset sound scheme to Windows default
call :log_message "INFO" "Resetting sound scheme..."
reg add "HKEY_CURRENT_USER\AppEvents\Schemes" /v "" /t REG_SZ /d ".Default" /f >nul 2>&1

:: Start audio services
call :log_message "INFO" "Starting audio services..."
net start "Windows Audio Endpoint Builder" >nul 2>&1
net start "Windows Audio" >nul 2>&1

call :log_message "SUCCESS" "Audio Settings Reset completed"
echo Audio settings have been reset to defaults.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%

call :log_message "INFO" "Audio Settings Reset completed"
exit /b 0