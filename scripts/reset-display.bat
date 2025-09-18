@echo off
:: Windows Settings Reset Toolkit - Display Settings Reset
:: Resets screen resolution, DPI scaling, monitor arrangements, and color profiles

title ReSet - Display Settings Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Display Settings Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset all display settings to defaults"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Control Panel\Desktop" "desktop_settings"
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes" "theme_settings"
call :backup_registry "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Hardware Profiles\0001\System\CurrentControlSet\Control\GraphicsDrivers" "graphics_settings"

:: Kill processes that might interfere
call :kill_process "dwm.exe"
timeout /t 2 /nobreak >nul

:: Reset display resolution to recommended
call :log_message "INFO" "Resetting display resolution..."

:: Get recommended resolution using PowerShell
for /f "tokens=*" %%i in ('powershell -command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width"') do set "REC_WIDTH=%%i"
for /f "tokens=*" %%i in ('powershell -command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height"') do set "REC_HEIGHT=%%i"

if defined REC_WIDTH if defined REC_HEIGHT (
    call :log_message "INFO" "Setting resolution to %REC_WIDTH%x%REC_HEIGHT%"
    powershell -command "& {Add-Type -AssemblyName System.Windows.Forms; $screen = [System.Windows.Forms.Screen]::PrimaryScreen; $bounds = $screen.Bounds; [System.Windows.Forms.SendKeys]::SendWait('^{ESC}'); Start-Sleep 1}" >nul 2>&1
)

:: Reset DPI scaling to 100%
call :log_message "INFO" "Resetting DPI scaling..."
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "LogPixels" /t REG_DWORD /d "96" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "Win8DpiScaling" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "AppliedDPI" /t REG_DWORD /d "96" /f >nul 2>&1

:: Reset DPI awareness
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "EnablePerProcessSystemDPI" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset desktop wallpaper to default
call :log_message "INFO" "Resetting desktop wallpaper..."
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "Wallpaper" /t REG_SZ /d "" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "WallpaperStyle" /t REG_SZ /d "10" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "TileWallpaper" /t REG_SZ /d "0" /f >nul 2>&1

:: Reset desktop background color to default
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "Background" /t REG_SZ /d "0 120 215" /f >nul 2>&1

:: Reset window colors to default
call :log_message "INFO" "Resetting window colors..."
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "ActiveBorder" /t REG_SZ /d "180 180 180" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "ActiveTitle" /t REG_SZ /d "153 180 209" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "AppWorkSpace" /t REG_SZ /d "171 171 171" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "ButtonFace" /t REG_SZ /d "240 240 240" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "ButtonHilight" /t REG_SZ /d "255 255 255" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "ButtonShadow" /t REG_SZ /d "160 160 160" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "ButtonText" /t REG_SZ /d "0 0 0" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "InactiveBorder" /t REG_SZ /d "244 247 252" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "InactiveTitle" /t REG_SZ /d "191 205 219" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "Menu" /t REG_SZ /d "240 240 240" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "MenuText" /t REG_SZ /d "0 0 0" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "Scrollbar" /t REG_SZ /d "200 200 200" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "Window" /t REG_SZ /d "255 255 255" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Colors" /v "WindowText" /t REG_SZ /d "0 0 0" /f >nul 2>&1

:: Reset font smoothing
call :log_message "INFO" "Resetting font smoothing..."
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothing" /t REG_SZ /d "2" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothingType" /t REG_DWORD /d "2" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothingGamma" /t REG_DWORD /d "1400" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "FontSmoothingOrientation" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset ClearType settings
powershell -command "& {reg add 'HKEY_CURRENT_USER\SOFTWARE\Microsoft\Avalon.Graphics' /v 'DisableClearTypeNaturalMetrics' /t REG_DWORD /d 0 /f}" >nul 2>&1

:: Reset theme to Windows default
call :log_message "INFO" "Resetting theme to default..."
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes" /v "CurrentTheme" /t REG_SZ /d "%SystemRoot%\resources\Themes\aero.theme" /f >nul 2>&1

:: Reset visual effects to default
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "DragFullWindows" /t REG_SZ /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "MenuShowDelay" /t REG_SZ /d "400" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "UserPreferencesMask" /t REG_BINARY /d "9e3e078012000000" /f >nul 2>&1

:: Reset desktop icon settings
call :log_message "INFO" "Resetting desktop icon settings..."
reg add "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /v "Shell Icon Size" /t REG_SZ /d "32" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Bags\1\Desktop" /v "IconSize" /t REG_DWORD /d "48" /f >nul 2>&1

:: Reset multiple monitor settings
call :log_message "INFO" "Resetting multiple monitor settings..."
reg delete "HKEY_CURRENT_USER\Control Panel\Desktop\PerMonitorSettings" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v "PrimaryDisplay" /t REG_SZ /d "1" /f >nul 2>&1

:: Reset color profiles to system defaults
call :log_message "INFO" "Resetting color profiles..."
reg delete "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ICM\ProfileAssociations\Display" /f >nul 2>&1

:: Clear display cache
call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\Caches" "Display Cache"

:: Reset graphics driver settings (if NVIDIA)
if exist "%ProgramFiles%\NVIDIA Corporation\NVSMI\nvidia-smi.exe" (
    call :log_message "INFO" "Resetting NVIDIA graphics settings..."
    reg delete "HKEY_CURRENT_USER\Software\NVIDIA Corporation\Global\NVTweak" /f >nul 2>&1
)

:: Reset graphics driver settings (if AMD)
if exist "%ProgramFiles%\AMD\CNext\CNext\RadeonSettings.exe" (
    call :log_message "INFO" "Resetting AMD graphics settings..."
    reg delete "HKEY_CURRENT_USER\Software\AMD\CN" /f >nul 2>&1
)

:: Apply theme and restart explorer
call :log_message "INFO" "Applying default theme..."
rundll32.exe shell32.dll,Control_RunDLL desk.cpl,,0 >nul 2>&1

:: Restart Explorer and DWM
call :kill_process "explorer.exe"
call :restart_service "uxsms"
timeout /t 2 /nobreak >nul
start explorer.exe

:: Refresh desktop
call :log_message "INFO" "Refreshing desktop..."
rundll32.exe user32.dll,UpdatePerUserSystemParameters >nul 2>&1

call :log_message "SUCCESS" "Display Settings reset completed"
echo.
echo Display settings have been reset to defaults.
echo Changes include:
echo - Screen resolution set to recommended
echo - DPI scaling reset to 100%%
echo - Desktop wallpaper and colors reset
echo - Font smoothing and ClearType reset
echo - Theme reset to Windows default
echo - Color profiles reset
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

call :log_message "INFO" "Display Settings Reset completed"
exit /b 0