@echo off
:: Windows Settings Reset Toolkit - Power Management Reset
:: Resets power plans, sleep/hibernate options, and display timeout settings

title ReSet - Power Management Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Power Management Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset power management settings to defaults"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power" "power_settings"
call :backup_registry "HKEY_CURRENT_USER\Control Panel\PowerCfg" "user_power_settings"

:: Reset to balanced power plan
call :log_message "INFO" "Setting power plan to Balanced..."
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1

:: Reset display timeout settings
call :log_message "INFO" "Resetting display timeout settings..."
powercfg /change monitor-timeout-ac 10 >nul 2>&1
powercfg /change monitor-timeout-dc 5 >nul 2>&1

:: Reset sleep settings
call :log_message "INFO" "Resetting sleep settings..."
powercfg /change standby-timeout-ac 30 >nul 2>&1
powercfg /change standby-timeout-dc 15 >nul 2>&1

:: Reset hibernate settings
call :log_message "INFO" "Resetting hibernate settings..."
powercfg /change hibernate-timeout-ac 0 >nul 2>&1
powercfg /change hibernate-timeout-dc 0 >nul 2>&1

:: Enable hibernate
powercfg /hibernate on >nul 2>&1

:: Reset USB selective suspend
call :log_message "INFO" "Resetting USB power settings..."
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 >nul 2>&1
powercfg /setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 >nul 2>&1

:: Reset processor power management
call :log_message "INFO" "Resetting processor power management..."
powercfg /setacvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 100 >nul 2>&1
powercfg /setdcvalueindex SCHEME_CURRENT 54533251-82be-4824-96c1-47b60b740d00 bc5038f7-23e0-4960-96da-33abaf5935ec 50 >nul 2>&1

:: Reset WiFi adapter power management
powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 >nul 2>&1
powercfg /setdcvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3 >nul 2>&1

:: Apply settings
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1

:: Reset power button action
call :log_message "INFO" "Resetting power button actions..."
powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 1 >nul 2>&1
powercfg /setdcvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 1 >nul 2>&1

:: Reset lid close action (for laptops)
powercfg /setacvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 1 >nul 2>&1
powercfg /setdcvalueindex SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 1 >nul 2>&1

:: Clear any custom power schemes (keep only built-in ones)
call :log_message "INFO" "Removing custom power schemes..."
for /f "tokens=4" %%i in ('powercfg /list ^| findstr /v "Balanced\|High\|Power\|Ultimate"') do (
    powercfg /delete %%i >nul 2>&1
)

call :log_message "SUCCESS" "Power Management Reset completed"
echo.
echo Power management settings have been reset to defaults.
echo Changes include:
echo - Power plan set to Balanced
echo - Display timeout: 10 min (AC), 5 min (battery)
echo - Sleep timeout: 30 min (AC), 15 min (battery)
echo - Hibernate enabled
echo - USB selective suspend enabled
echo - Processor power management reset
echo - Power button actions reset
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Power Management Reset completed"
exit /b 0