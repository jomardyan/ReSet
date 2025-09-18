@echo off
:: Windows Settings Reset Toolkit - Windows Defender Reset
:: Resets Windows Defender settings, clears quarantine, and restores real-time protection

title ReSet - Windows Defender Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Windows Defender Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset Windows Defender settings and clear quarantine"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" "defender_policies"
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender" "defender_settings"

:: Reset Windows Defender policies
call :log_message "INFO" "Resetting Windows Defender policies..."
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender" /f >nul 2>&1

:: Enable real-time protection
call :log_message "INFO" "Enabling real-time protection..."
powershell -command "Set-MpPreference -DisableRealtimeMonitoring $false" >nul 2>&1

:: Reset scan settings to default
call :log_message "INFO" "Resetting scan settings..."
powershell -command "Set-MpPreference -ScanAvgCPULoadFactor 50" >nul 2>&1
powershell -command "Set-MpPreference -CheckForSignaturesBeforeRunningScan $true" >nul 2>&1

:: Clear exclusions
call :log_message "INFO" "Clearing exclusions..."
powershell -command "Remove-MpPreference -ExclusionPath (Get-MpPreference).ExclusionPath" >nul 2>&1
powershell -command "Remove-MpPreference -ExclusionExtension (Get-MpPreference).ExclusionExtension" >nul 2>&1
powershell -command "Remove-MpPreference -ExclusionProcess (Get-MpPreference).ExclusionProcess" >nul 2>&1

:: Reset threat actions to default
call :log_message "INFO" "Resetting threat actions..."
powershell -command "Set-MpPreference -LowThreatDefaultAction Quarantine" >nul 2>&1
powershell -command "Set-MpPreference -ModerateThreatDefaultAction Quarantine" >nul 2>&1
powershell -command "Set-MpPreference -HighThreatDefaultAction Quarantine" >nul 2>&1
powershell -command "Set-MpPreference -SevereThreatDefaultAction Quarantine" >nul 2>&1

:: Clear quarantine (with user confirmation)
if /i not "%SILENT_MODE%"=="true" (
    echo.
    echo WARNING: This will clear the Windows Defender quarantine.
    set /p "CLEAR_QUARANTINE=Clear quarantine? (y/N): "
    if /i "%CLEAR_QUARANTINE%"=="y" (
        call :log_message "INFO" "Clearing quarantine..."
        powershell -command "Remove-MpThreat -All" >nul 2>&1
    )
) else (
    call :log_message "INFO" "Clearing quarantine (silent mode)..."
    powershell -command "Remove-MpThreat -All" >nul 2>&1
)

:: Update definitions
call :log_message "INFO" "Updating virus definitions..."
powershell -command "Update-MpSignature" >nul 2>&1

:: Reset Windows Defender Firewall to defaults
call :log_message "INFO" "Resetting Windows Defender Firewall..."
netsh advfirewall reset >nul 2>&1

:: Enable Windows Defender Firewall for all profiles
netsh advfirewall set allprofiles state on >nul 2>&1

:: Reset notification settings
call :log_message "INFO" "Resetting notification settings..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Defender\UX Configuration" /v "Notification_Suppress" /t REG_DWORD /d "0" /f >nul 2>&1

call :log_message "SUCCESS" "Windows Defender Reset completed"
echo.
echo Windows Defender has been reset to defaults.
echo Changes include:
echo - Real-time protection enabled
echo - Exclusions cleared
echo - Threat actions reset to quarantine
echo - Firewall reset and enabled
echo - Virus definitions updated
echo - Quarantine cleared (if confirmed)
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Windows Defender Reset completed"
exit /b 0