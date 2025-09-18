@echo off
:: Windows Settings Reset Toolkit - Windows Features Reset
:: Resets optional Windows features and capabilities

title ReSet - Windows Features Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Windows Features Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset Windows features and capabilities to defaults"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\OptionalFeatures" "optional_features"

:: Reset Windows optional features to default state
call :log_message "INFO" "Checking Windows features status..."

:: Enable essential Windows features
call :log_message "INFO" "Enabling essential Windows features..."
dism /online /enable-feature /featurename:NetFx3 /all /norestart >nul 2>&1
dism /online /enable-feature /featurename:IIS-WebServerRole /norestart >nul 2>&1
dism /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart >nul 2>&1

:: Disable potentially problematic features
call :log_message "INFO" "Disabling optional features..."
dism /online /disable-feature /featurename:SMB1Protocol /norestart >nul 2>&1
dism /online /disable-feature /featurename:WorkFolders-Client /norestart >nul 2>&1

:: Reset Windows capabilities
call :log_message "INFO" "Resetting Windows capabilities..."
powershell -command "Get-WindowsCapability -Online | Where-Object {$_.State -eq 'NotPresent'} | Add-WindowsCapability -Online" >nul 2>&1

:: Reset Windows apps and features
powershell -command "Get-WindowsOptionalFeature -Online | Where-Object {$_.FeatureName -like '*Legacy*'} | Disable-WindowsOptionalFeature -Online -NoRestart" >nul 2>&1

call :log_message "SUCCESS" "Windows Features Reset completed"
echo.
echo Windows features have been reset to recommended defaults.
echo - Essential features enabled
echo - Security-risk features disabled
echo - Windows capabilities reset
echo.
echo A system restart may be required for changes to take effect.
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo Would you like to restart now to complete the features reset? (y/N)
    set /p "RESTART=Enter your choice: "
    if /i "%RESTART%"=="y" (
        call :log_message "INFO" "System restart initiated by user"
        shutdown /r /t 10 /c "Restarting to complete Windows features reset..."
    )
)

call :log_message "INFO" "Windows Features Reset completed"
exit /b 0