@echo off
:: Windows Settings Reset Toolkit - Browser Settings Reset
:: Resets Internet Explorer, Edge, Firefox, and Chrome browser settings

title ReSet - Browser Settings Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Browser Settings Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset browser settings and clear browsing data for all browsers (IE, Edge, Chrome, Firefox)"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer" "ie_settings"
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Edge" "edge_settings"
call :backup_registry "HKEY_CURRENT_USER\Software\Google\Chrome" "chrome_settings"
call :backup_registry "HKEY_CURRENT_USER\Software\Mozilla\Firefox" "firefox_settings"

:: Close browsers
call :log_message "INFO" "Closing browser processes..."
call :kill_process "iexplore.exe"
call :kill_process "msedge.exe"
call :kill_process "chrome.exe"
call :kill_process "firefox.exe"
timeout /t 3 /nobreak >nul

:: Reset Internet Explorer
call :log_message "INFO" "Resetting Internet Explorer settings..."

:: Clear browsing history
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255 >nul 2>&1

:: Reset homepage
reg add "HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer\Main" /v "Start Page" /t REG_SZ /d "about:blank" /f >nul 2>&1

:: Reset search engine
reg add "HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer\Main" /v "Search Page" /t REG_SZ /d "https://www.bing.com" /f >nul 2>&1

:: Reset security zones
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" /v "1400" /t REG_DWORD /d "0" /f >nul 2>&1

:: Reset proxy settings
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "ProxyEnable" /t REG_DWORD /d "0" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "ProxyServer" /f >nul 2>&1

:: Clear saved passwords
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer\IntelliForms\Storage2" /f >nul 2>&1

:: Reset Edge (Chromium)
call :log_message "INFO" "Resetting Microsoft Edge settings..."

:: Clear Edge user data
set "EDGE_DATA=%LOCALAPPDATA%\Microsoft\Edge\User Data"
if exist "%EDGE_DATA%" (
    call :clear_folder "%EDGE_DATA%\Default\Cache" "Edge Cache"
    call :clear_folder "%EDGE_DATA%\Default\Cookies" "Edge Cookies"
    call :clear_folder "%EDGE_DATA%\Default\History" "Edge History"
    call :clear_folder "%EDGE_DATA%\Default\Sessions" "Edge Sessions"
    
    :: Reset Edge preferences (if file exists)
    if exist "%EDGE_DATA%\Default\Preferences" (
        del "%EDGE_DATA%\Default\Preferences" >nul 2>&1
    )
)

:: Reset default browser setting
call :log_message "INFO" "Clearing default browser setting..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice" /f >nul 2>&1

:: Clear Windows WebView cache
call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\WebCache" "WebView Cache"

:: Reset Windows Search web results
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" /v "BingSearchEnabled" /t REG_DWORD /d "0" /f >nul 2>&1

:: Reset Google Chrome
call :log_message "INFO" "Resetting Google Chrome settings..."

:: Check if Chrome is installed
set "CHROME_DATA=%LOCALAPPDATA%\Google\Chrome\User Data"
if exist "%CHROME_DATA%" (
    call :log_message "INFO" "Chrome installation detected, clearing data..."
    
    :: Clear Chrome user data
    call :clear_folder "%CHROME_DATA%\Default\Cache" "Chrome Cache"
    call :clear_folder "%CHROME_DATA%\Default\Cookies" "Chrome Cookies"
    call :clear_folder "%CHROME_DATA%\Default\History" "Chrome History"
    call :clear_folder "%CHROME_DATA%\Default\Sessions" "Chrome Sessions"
    call :clear_folder "%CHROME_DATA%\Default\Local Storage" "Chrome Local Storage"
    call :clear_folder "%CHROME_DATA%\Default\IndexedDB" "Chrome IndexedDB"
    call :clear_folder "%CHROME_DATA%\Default\Web Data" "Chrome Web Data"
    
    :: Reset Chrome preferences (if file exists)
    if exist "%CHROME_DATA%\Default\Preferences" (
        del "%CHROME_DATA%\Default\Preferences" >nul 2>&1
        call :log_message "SUCCESS" "Chrome preferences reset"
    )
    
    :: Reset Chrome shortcuts
    if exist "%CHROME_DATA%\Default\Shortcuts" (
        del "%CHROME_DATA%\Default\Shortcuts" >nul 2>&1
    )
    
    :: Clear Chrome extensions
    call :clear_folder "%CHROME_DATA%\Default\Extensions" "Chrome Extensions"
    
    :: Reset Chrome bookmarks (with confirmation)
    if /i not "%SILENT_MODE%"=="true" (
        echo.
        set /p "RESET_CHROME_BOOKMARKS=Reset Chrome bookmarks? (y/N): "
        if /i "%RESET_CHROME_BOOKMARKS%"=="y" (
            if exist "%CHROME_DATA%\Default\Bookmarks" (
                del "%CHROME_DATA%\Default\Bookmarks" >nul 2>&1
                call :log_message "INFO" "Chrome bookmarks reset"
            )
        )
    )
) else (
    call :log_message "INFO" "Google Chrome not installed or not found"
)

:: Reset Mozilla Firefox
call :log_message "INFO" "Resetting Mozilla Firefox settings..."

:: Check if Firefox is installed
set "FIREFOX_DATA=%APPDATA%\Mozilla\Firefox\Profiles"
if exist "%FIREFOX_DATA%" (
    call :log_message "INFO" "Firefox installation detected, clearing data..."
    
    :: Find Firefox profile directories
    for /d %%i in ("%FIREFOX_DATA%\*") do (
        call :log_message "INFO" "Processing Firefox profile: %%~nxi"
        
        :: Clear Firefox cache and data
        call :clear_folder "%%i\cache2" "Firefox Cache"
        call :clear_folder "%%i\startupCache" "Firefox Startup Cache"
        call :clear_folder "%%i\thumbnails" "Firefox Thumbnails"
        call :clear_folder "%%i\sessionstore-backups" "Firefox Session Store"
        
        :: Clear Firefox cookies and history
        if exist "%%i\cookies.sqlite" del "%%i\cookies.sqlite" >nul 2>&1
        if exist "%%i\places.sqlite" del "%%i\places.sqlite" >nul 2>&1
        if exist "%%i\formhistory.sqlite" del "%%i\formhistory.sqlite" >nul 2>&1
        if exist "%%i\downloads.sqlite" del "%%i\downloads.sqlite" >nul 2>&1
        
        :: Reset Firefox preferences (with confirmation)
        if /i not "%SILENT_MODE%"=="true" (
            set /p "RESET_FF_PREFS=Reset Firefox preferences for profile %%~nxi? (y/N): "
            if /i "!RESET_FF_PREFS!"=="y" (
                if exist "%%i\prefs.js" del "%%i\prefs.js" >nul 2>&1
                if exist "%%i\user.js" del "%%i\user.js" >nul 2>&1
                call :log_message "INFO" "Firefox preferences reset for profile %%~nxi"
            )
        )
        
        :: Clear Firefox extensions
        call :clear_folder "%%i\extensions" "Firefox Extensions"
        
        :: Reset Firefox bookmarks (with confirmation)
        if /i not "%SILENT_MODE%"=="true" (
            set /p "RESET_FF_BOOKMARKS=Reset Firefox bookmarks for profile %%~nxi? (y/N): "
            if /i "!RESET_FF_BOOKMARKS!"=="y" (
                if exist "%%i\places.sqlite" del "%%i\places.sqlite" >nul 2>&1
                if exist "%%i\bookmarkbackups" call :clear_folder "%%i\bookmarkbackups" "Firefox Bookmark Backups"
                call :log_message "INFO" "Firefox bookmarks reset for profile %%~nxi"
            )
        )
    )
    
    call :log_message "SUCCESS" "Firefox reset completed"
) else (
    call :log_message "INFO" "Mozilla Firefox not installed or not found"
)

call :log_message "SUCCESS" "Browser Settings Reset completed"
echo.
echo Browser settings have been reset to defaults for all browsers.
echo Changes include:
echo.
echo Internet Explorer:
echo - Settings reset and browsing history cleared
echo - Homepage reset to blank, search engine reset to Bing
echo - Security zones and proxy settings reset
echo - Saved passwords cleared
echo.
echo Microsoft Edge:
echo - Cache, cookies, history, and sessions cleared
echo - Preferences reset
echo.
echo Google Chrome (if installed):
echo - Cache, cookies, history, and sessions cleared
echo - Preferences and extensions reset
echo - Local storage and IndexedDB cleared
echo - Bookmarks reset (if confirmed)
echo.
echo Mozilla Firefox (if installed):
echo - Cache, cookies, history, and downloads cleared
echo - Session store and thumbnails cleared
echo - Preferences and extensions reset (if confirmed)
echo - Bookmarks reset (if confirmed)
echo.
echo Additional:
echo - Default browser setting cleared
echo - Windows WebView cache cleared
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Browser Settings Reset completed"
exit /b 0