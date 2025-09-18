@echo off
:: Windows Settings Reset Toolkit - Windows Shell Reset
:: Resets Windows Explorer settings, folder views, and shell associations

title ReSet - Windows Shell Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Windows Shell Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset Windows Explorer settings and folder views"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" "explorer_settings"
call :backup_registry "HKEY_CURRENT_USER\Software\Classes" "file_associations"

:: Kill Explorer process
call :log_message "INFO" "Stopping Windows Explorer..."
call :kill_process "explorer.exe"
timeout /t 2 /nobreak >nul

:: Reset Explorer advanced settings
call :log_message "INFO" "Resetting Explorer advanced settings..."
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t REG_DWORD /d "2" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowSuperHidden" /t REG_DWORD /d "0" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "LaunchTo" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowCompColor" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowInfoTip" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset folder view settings
call :log_message "INFO" "Resetting folder view settings..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\Bags" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\Shell\BagMRU" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\ShellNoRoam\Bags" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\ShellNoRoam\BagMRU" /f >nul 2>&1

:: Reset default folder view to Details
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "FolderContentsInfoTip" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset context menu settings
call :log_message "INFO" "Resetting context menu settings..."
reg delete "HKEY_CURRENT_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f >nul 2>&1

:: Reset Quick Access settings
call :log_message "INFO" "Resetting Quick Access..."
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowFrequent" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v "ShowRecent" /t REG_DWORD /d "1" /f >nul 2>&1

:: Clear Quick Access pinned folders
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon" /f >nul 2>&1

:: Reset thumbnail cache
call :log_message "INFO" "Clearing thumbnail cache..."
call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\Explorer" "Thumbnail Cache"

:: Reset Windows Explorer startup location to This PC
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "LaunchTo" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset status bar settings
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowStatusBar" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset preview pane
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowPreviewHandlers" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset navigation pane
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "NavPaneExpandToCurrentFolder" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "NavPaneShowAllFolders" /t REG_DWORD /d "0" /f >nul 2>&1

:: Reset file operations settings
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "TypeAhead" /t REG_DWORD /d "1" /f >nul 2>&1

:: Clear Windows Explorer history
call :log_message "INFO" "Clearing Explorer history..."
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU" /f >nul 2>&1

:: Reset ribbon settings
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon" /f >nul 2>&1

:: Restart Explorer
call :log_message "INFO" "Restarting Windows Explorer..."
start explorer.exe
timeout /t 3 /nobreak >nul

call :log_message "SUCCESS" "Windows Shell Reset completed"
echo.
echo Windows Explorer settings have been reset to defaults.
echo Changes include:
echo - Folder view settings reset
echo - Hidden files settings reset to default
echo - File extensions hidden by default
echo - Quick Access reset
echo - Context menus reset
echo - Thumbnail cache cleared
echo - Explorer history cleared
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Windows Shell Reset completed"
exit /b 0