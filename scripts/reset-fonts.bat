@echo off
:: Windows Settings Reset Toolkit - Fonts & Text Settings Reset
:: Resets system fonts, text scaling, and ClearType configuration

title ReSet - Fonts & Text Settings Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Fonts & Text Settings Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset fonts and text settings to defaults"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "system_fonts"
call :backup_registry "HKEY_CURRENT_USER\Control Panel\Desktop" "font_settings"

:: Reset system fonts to Windows defaults
call :log_message "INFO" "Resetting system fonts to defaults..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\GRE_Initialize" /v "GUIFont.Facename" /t REG_SZ /d "Segoe UI" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\GRE_Initialize" /v "GUIFont.Height" /t REG_DWORD /d "12" /f >nul 2>&1

:: Reset desktop icon font
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "IconFont" /t REG_BINARY /d "f4ffffff00000000000000009000000090000000010000000000500065006700000065000000200000005500490000000000000000000000000000000000000000000000000000" /f >nul 2>&1

:: Reset menu font
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "MenuFont" /t REG_BINARY /d "f4ffffff00000000000000009000000090000000010000000000500065006700000065000000200000005500490000000000000000000000000000000000000000000000000000" /f >nul 2>&1

:: Reset message box font
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "MessageFont" /t REG_BINARY /d "f4ffffff00000000000000009000000090000000010000000000500065006700000065000000200000005500490000000000000000000000000000000000000000000000000000" /f >nul 2>&1

:: Reset status bar font
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "StatusFont" /t REG_BINARY /d "f4ffffff00000000000000009000000090000000010000000000500065006700000065000000200000005500490000000000000000000000000000000000000000000000000000" /f >nul 2>&1

:: Reset caption font
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "CaptionFont" /t REG_BINARY /d "f4ffffff00000000000000009000000090000000010000000000500065006700000065000000200000005500490000000000000000000000000000000000000000000000000000" /f >nul 2>&1

:: Reset ClearType settings
call :log_message "INFO" "Resetting ClearType settings..."
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothing" /t REG_SZ /d "2" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothingType" /t REG_DWORD /d "2" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothingGamma" /t REG_DWORD /d "1400" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothingOrientation" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset text scaling to 100%
call :log_message "INFO" "Resetting text scaling to 100%%..."
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "LogPixels" /t REG_DWORD /d "96" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "AppliedDPI" /t REG_DWORD /d "96" /f >nul 2>&1

:: Remove custom installed fonts (with confirmation)
if /i not "%SILENT_MODE%"=="true" (
    echo.
    echo WARNING: This can remove custom installed fonts.
    set /p "REMOVE_FONTS=Remove custom installed fonts? (y/N): "
    if /i "%REMOVE_FONTS%"=="y" (
        call :log_message "INFO" "Removing custom fonts..."
        :: Remove fonts from user profile
        call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\Fonts" "User Fonts"
    )
)

:: Reset font fallback settings
call :log_message "INFO" "Resetting font fallback settings..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink" /f >nul 2>&1

:: Reset font substitution
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" /f >nul 2>&1

:: Add default font substitutions
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" /v "Arial" /t REG_SZ /d "Arial" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontSubstitutes" /v "Times New Roman" /t REG_SZ /d "Times New Roman" /f >nul 2>&1

:: Reset text rendering settings
reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Avalon.Graphics" /v "DisableClearTypeNaturalMetrics" /t REG_DWORD /d "0" /f >nul 2>&1

:: Refresh font cache
call :log_message "INFO" "Refreshing font cache..."
call :restart_service "FontCache"

call :log_message "SUCCESS" "Fonts & Text Settings Reset completed"
echo.
echo Fonts and text settings have been reset to defaults.
echo Changes include:
echo - System fonts reset to Segoe UI
echo - ClearType enabled and configured
echo - Text scaling reset to 100%%
echo - Font substitution reset
echo - Font cache refreshed
echo.
echo Some changes may require a sign-out or restart to take full effect.
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo Would you like to sign out now to complete the reset? (y/N)
    set /p "SIGNOUT=Enter your choice: "
    if /i "%SIGNOUT%"=="y" (
        call :log_message "INFO" "User sign-out initiated by user"
        shutdown /l
    )
)

call :log_message "INFO" "Fonts & Text Settings Reset completed"
exit /b 0