@echo off
:: Windows Settings Reset Toolkit - Start Menu & Taskbar Reset
:: Resets Start Menu layout, taskbar settings, and notification area

title ReSet - Start Menu & Taskbar Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Start Menu & Taskbar Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset Start Menu layout and taskbar settings"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "explorer_advanced"
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" "taskbar_settings"
call :create_backup "start_menu_layout" "%LOCALAPPDATA%\Microsoft\Windows\Shell"

:: Kill Explorer process
call :log_message "INFO" "Stopping Windows Explorer..."
call :kill_process "explorer.exe"
timeout /t 2 /nobreak >nul

:: Reset Start Menu layout
call :log_message "INFO" "Resetting Start Menu layout..."

:: Clear Start Menu cache
call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\Caches" "Start Menu Cache"
call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\Shell" "Shell Layout Cache"

:: Reset Start Menu tiles
call :clear_folder "%LOCALAPPDATA%\TileDataLayer" "Tile Data"

:: Remove custom Start Menu layout
if exist "%LOCALAPPDATA%\Microsoft\Windows\Shell\LayoutModification.xml" (
    del "%LOCALAPPDATA%\Microsoft\Windows\Shell\LayoutModification.xml" >nul 2>&1
    call :log_message "SUCCESS" "Custom Start Menu layout removed"
)

:: Reset Start Menu registry settings
call :log_message "INFO" "Resetting Start Menu registry settings..."

:: Reset Start Menu size and position
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartPage" /f >nul 2>&1

:: Reset Recently added apps
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-314559Enabled" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset Start Menu search
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d "0" /f >nul 2>&1

:: Reset taskbar settings
call :log_message "INFO" "Resetting taskbar settings..."

:: Reset taskbar position (bottom)
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" /v "Settings" /t REG_BINARY /d "30000000feffffff7af400000300000030000000300000000000000000040000403e01000000000001000000" /f >nul 2>&1

:: Reset taskbar auto-hide
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAutoHideInTabletMode" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAutoHideInDesktopMode" /t REG_DWORD /d "0" /f >nul 2>&1

:: Reset taskbar button grouping
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarGlomLevel" /t REG_DWORD /d "0" /f >nul 2>&1

:: Reset taskbar size
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarSizeMove" /t REG_DWORD /d "0" /f >nul 2>&1

:: Reset taskbar transparency
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset notification area
call :log_message "INFO" "Resetting notification area..."

:: Clear notification area settings
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\TrayNotify" /f >nul 2>&1

:: Reset system tray icons
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "EnableBalloonTips" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset clock settings
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSecondsInSystemClock" /t REG_DWORD /d "0" /f >nul 2>&1

:: Reset Jump Lists
call :log_message "INFO" "Clearing Jump Lists..."
call :clear_folder "%APPDATA%\Microsoft\Windows\Recent\AutomaticDestinations" "Jump Lists"
call :clear_folder "%APPDATA%\Microsoft\Windows\Recent\CustomDestinations" "Custom Jump Lists"

:: Reset pinned items
call :log_message "INFO" "Clearing pinned items..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" /f >nul 2>&1

:: Clear taskbar thumbnail cache
call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\Explorer" "Taskbar Thumbnails"

:: Reset Windows 11 specific settings (if applicable)
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
if "%VERSION%" == "10.0" (
    :: Check build number for Windows 11
    for /f "tokens=3" %%k in ('ver') do set BUILD=%%k
    if !BUILD! geq 22000 (
        call :log_message "INFO" "Applying Windows 11 specific settings..."
        
        :: Reset Start Menu alignment (left)
        reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarAl" /t REG_DWORD /d "0" /f >nul 2>&1
        
        :: Reset widgets
        reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarDa" /t REG_DWORD /d "0" /f >nul 2>&1
        
        :: Reset chat icon
        reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TaskbarMn" /t REG_DWORD /d "0" /f >nul 2>&1
    )
)

:: Reset context menus
call :log_message "INFO" "Resetting context menus..."
reg delete "HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f >nul 2>&1

:: Clear recent documents
call :log_message "INFO" "Clearing recent documents..."
call :clear_folder "%APPDATA%\Microsoft\Windows\Recent" "Recent Documents"

:: Reset desktop icons
call :log_message "INFO" "Resetting desktop icon settings..."
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t REG_DWORD /d "2" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "SuperHidden" /t REG_DWORD /d "0" /f >nul 2>&1

:: Restart Explorer
call :log_message "INFO" "Restarting Windows Explorer..."
start explorer.exe
timeout /t 3 /nobreak >nul

:: Force refresh of Start Menu and taskbar
call :log_message "INFO" "Refreshing Start Menu and taskbar..."
taskkill /f /im StartMenuExperienceHost.exe >nul 2>&1
timeout /t 2 /nobreak >nul

call :log_message "SUCCESS" "Start Menu & Taskbar Reset completed"
echo.
echo Start Menu and taskbar have been reset to defaults.
echo Changes include:
echo - Start Menu layout reset
echo - Taskbar position and settings reset
echo - Notification area reset
echo - Pinned items cleared
echo - Jump Lists cleared
echo - Recent documents cleared
echo.
echo Some changes may require a sign-out to take full effect.
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

call :log_message "INFO" "Start Menu & Taskbar Reset completed"
exit /b 0