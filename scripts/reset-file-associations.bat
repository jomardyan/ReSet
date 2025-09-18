@echo off
:: Windows Settings Reset Toolkit - File Associations Reset
:: Resets default programs and file type associations

title ReSet - File Associations Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting File Associations Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset file associations and default programs"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" "file_extensions"
call :backup_registry "HKEY_CURRENT_USER\Software\Classes" "user_file_classes"

:: Reset common file associations to Windows defaults
call :log_message "INFO" "Resetting file associations to Windows defaults..."

:: Reset text files
reg add "HKEY_CURRENT_USER\Software\Classes\.txt" /ve /t REG_SZ /d "txtfile" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Classes\txtfile\shell\open\command" /ve /t REG_SZ /d "notepad.exe %%1" /f >nul 2>&1

:: Reset image files
reg add "HKEY_CURRENT_USER\Software\Classes\.jpg" /ve /t REG_SZ /d "jpegfile" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Classes\.png" /ve /t REG_SZ /d "pngfile" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Classes\.bmp" /ve /t REG_SZ /d "Paint.Picture" /f >nul 2>&1

:: Reset document files
reg add "HKEY_CURRENT_USER\Software\Classes\.pdf" /ve /t REG_SZ /d "AcroExch.Document" /f >nul 2>&1

:: Reset web files
reg add "HKEY_CURRENT_USER\Software\Classes\.html" /ve /t REG_SZ /d "htmlfile" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Classes\.htm" /ve /t REG_SZ /d "htmlfile" /f >nul 2>&1

:: Clear custom file extension associations
call :log_message "INFO" "Clearing custom file extension settings..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" /f >nul 2>&1

:: Reset default browser setting (to system default)
call :log_message "INFO" "Resetting default browser to system default..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https" /f >nul 2>&1

:: Reset protocol associations
call :log_message "INFO" "Resetting protocol associations..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\mailto" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\ftp" /f >nul 2>&1

:: Clear OpenWith choices
call :log_message "INFO" "Clearing OpenWith choices..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts" /f >nul 2>&1

:: Reset auto-play settings
call :log_message "INFO" "Resetting auto-play settings..."
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" /f >nul 2>&1

:: Clear MRU (Most Recently Used) lists
call :log_message "INFO" "Clearing MRU lists..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU" /f >nul 2>&1

:: Rebuild icon cache
call :log_message "INFO" "Rebuilding icon cache..."
call :clear_folder "%LOCALAPPDATA%\IconCache.db" "Icon Cache"
del "%LOCALAPPDATA%\IconCache.db" >nul 2>&1

:: Force refresh of file associations
call :log_message "INFO" "Refreshing file associations..."
sfc /verifyonly >nul 2>&1

call :log_message "SUCCESS" "File Associations Reset completed"
echo.
echo File associations have been reset to Windows defaults.
echo Changes include:
echo - Common file types reset to default programs
echo - Custom file associations cleared
echo - Protocol associations reset
echo - OpenWith choices cleared
echo - Auto-play settings reset
echo - Icon cache rebuilt
echo.
echo You may need to sign out and sign back in for all changes to take effect.
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

call :log_message "INFO" "File Associations Reset completed"
exit /b 0