@echo off
:: Windows Settings Reset Toolkit - Input Devices Reset
:: Resets mouse, keyboard, and accessibility settings

title ReSet - Input Devices Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Input Devices Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset mouse, keyboard, and accessibility settings"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Control Panel\Mouse" "mouse_settings"
call :backup_registry "HKEY_CURRENT_USER\Control Panel\Keyboard" "keyboard_settings"
call :backup_registry "HKEY_CURRENT_USER\Control Panel\Accessibility" "accessibility_settings"

:: Reset mouse settings
call :log_message "INFO" "Resetting mouse settings..."
reg add "HKEY_CURRENT_USER\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "6" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "10" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Mouse" /v "MouseSensitivity" /t REG_SZ /d "10" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Mouse" /v "SwapMouseButtons" /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Mouse" /v "DoubleClickSpeed" /t REG_SZ /d "500" /f >nul 2>&1

:: Reset keyboard settings
call :log_message "INFO" "Resetting keyboard settings..."
reg add "HKEY_CURRENT_USER\Control Panel\Keyboard" /v "KeyboardDelay" /t REG_SZ /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Keyboard" /v "KeyboardSpeed" /t REG_SZ /d "31" /f >nul 2>&1

:: Reset accessibility settings
call :log_message "INFO" "Resetting accessibility settings..."
reg add "HKEY_CURRENT_USER\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "506" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Accessibility\FilterKeys" /v "Flags" /t REG_SZ /d "126" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f >nul 2>&1

:: Reset mouse pointer scheme
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "" /t REG_SZ /d "" /f >nul 2>&1

call :log_message "SUCCESS" "Input Devices Reset completed"
echo.
echo Input device settings have been reset to defaults.
echo - Mouse sensitivity and buttons reset
echo - Keyboard repeat rate reset
echo - Accessibility features reset
echo - Mouse pointer scheme reset
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Input Devices Reset completed"
exit /b 0