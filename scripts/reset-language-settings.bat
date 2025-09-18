@echo off
:: Windows Settings Reset Toolkit - Language & Regional Settings Reset
:: Resets system locale, date/time formats, number formats, and keyboard layouts

title ReSet - Language & Regional Settings Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Language & Regional Settings Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset all language and regional settings to defaults"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Control Panel\International" "international_settings"
call :backup_registry "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls" "nls_settings"
call :backup_registry "HKEY_CURRENT_USER\Keyboard Layout" "keyboard_layout"

:: Reset International Settings
call :log_message "INFO" "Resetting international settings..."

:: Reset system locale to English (United States)
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "LocaleName" /t REG_SZ /d "en-US" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sCountry" /t REG_SZ /d "United States" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sLanguage" /t REG_SZ /d "ENU" /f >nul 2>&1

:: Reset date formats
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sShortDate" /t REG_SZ /d "M/d/yyyy" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sLongDate" /t REG_SZ /d "dddd, MMMM d, yyyy" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sYearMonth" /t REG_SZ /d "MMMM yyyy" /f >nul 2>&1

:: Reset time formats
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sTimeFormat" /t REG_SZ /d "h:mm:ss tt" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sShortTime" /t REG_SZ /d "h:mm tt" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "s1159" /t REG_SZ /d "AM" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "s2359" /t REG_SZ /d "PM" /f >nul 2>&1

:: Reset number formats
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sDecimal" /t REG_SZ /d "." /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sThousand" /t REG_SZ /d "," /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sGrouping" /t REG_SZ /d "3;0" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "iDigits" /t REG_SZ /d "2" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "iLZero" /t REG_SZ /d "1" /f >nul 2>&1

:: Reset currency formats
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sCurrency" /t REG_SZ /d "$" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sMonDecimalSep" /t REG_SZ /d "." /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "sMonThousandSep" /t REG_SZ /d "," /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "iCurrDigits" /t REG_SZ /d "2" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "iCurrency" /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "iNegCurr" /t REG_SZ /d "0" /f >nul 2>&1

:: Reset measurement system
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "iMeasure" /t REG_SZ /d "1" /f >nul 2>&1

:: Reset first day of week
reg add "HKEY_CURRENT_USER\Control Panel\International" /v "iFirstDayOfWeek" /t REG_SZ /d "6" /f >nul 2>&1

:: Reset keyboard layouts
call :log_message "INFO" "Resetting keyboard layouts..."

:: Remove all custom keyboard layouts
reg delete "HKEY_CURRENT_USER\Keyboard Layout\Preload" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Keyboard Layout\Substitutes" /f >nul 2>&1

:: Add default US keyboard layout
reg add "HKEY_CURRENT_USER\Keyboard Layout\Preload" /v "1" /t REG_SZ /d "00000409" /f >nul 2>&1

:: Reset input method settings
reg add "HKEY_CURRENT_USER\Control Panel\International\User Profile" /v "Languages" /t REG_MULTI_SZ /d "en-US" /f >nul 2>&1

:: Clear language profile cache
call :log_message "INFO" "Clearing language profile cache..."
reg delete "HKEY_CURRENT_USER\Control Panel\International\User Profile\en-US" /f >nul 2>&1

:: Reset system locale for all users (requires restart)
call :log_message "INFO" "Setting system locale..."
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\Language" /v "Default" /t REG_SZ /d "0409" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\Language" /v "InstallLanguage" /t REG_SZ /d "0409" /f >nul 2>&1

:: Reset regional settings for new users
reg add "HKEY_USERS\.DEFAULT\Control Panel\International" /v "LocaleName" /t REG_SZ /d "en-US" /f >nul 2>&1
reg add "HKEY_USERS\.DEFAULT\Control Panel\International" /v "sCountry" /t REG_SZ /d "United States" /f >nul 2>&1

:: Force update of regional settings
call :log_message "INFO" "Applying regional settings..."
rundll32.exe shell32.dll,Control_RunDLL intl.cpl,,/f >nul 2>&1

:: Kill and restart Explorer to apply changes
call :kill_process "explorer.exe"
timeout /t 2 /nobreak >nul
start explorer.exe

call :log_message "SUCCESS" "Language & Regional Settings reset completed"
echo.
echo Language and regional settings have been reset to defaults.
echo Some changes may require a system restart to take full effect.
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo Would you like to restart now to complete the reset? (y/N)
    set /p "RESTART=Enter your choice: "
    if /i "%RESTART%"=="y" (
        call :log_message "INFO" "System restart initiated by user"
        shutdown /r /t 10 /c "Restarting to complete language settings reset..."
    )
)

call :log_message "INFO" "Language & Regional Settings Reset completed"
exit /b 0