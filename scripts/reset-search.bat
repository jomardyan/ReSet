@echo off
:: Windows Settings Reset Toolkit - Windows Search Reset
:: Rebuilds search index, resets search options, and clears search history

title ReSet - Windows Search Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Windows Search Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset Windows Search and rebuild search index"

:: Create backups
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SearchSettings" "search_settings"
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search" "windows_search"

:: Stop Windows Search services
call :log_message "INFO" "Stopping Windows Search services..."
net stop wsearch /y >nul 2>&1
net stop "Windows Search" /y >nul 2>&1
call :kill_process "SearchIndexer.exe"
call :kill_process "SearchProtocolHost.exe"

:: Clear search index
call :log_message "INFO" "Clearing search index..."
call :clear_folder "%ProgramData%\Microsoft\Search\Data" "Search Index Data"

:: Delete search database
if exist "%ProgramData%\Microsoft\Search\Data\Applications\Windows\Windows.edb" (
    del "%ProgramData%\Microsoft\Search\Data\Applications\Windows\Windows.edb" >nul 2>&1
    call :log_message "SUCCESS" "Search database cleared"
)

:: Reset search settings in registry
call :log_message "INFO" "Resetting search settings..."

:: Reset Windows Search configuration
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search" /v "EnableFindMyFiles" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\Preferences" /v "EnableContentIndexing" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset Cortana search settings
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SearchSettings" /v "IsAADCloudSearchEnabled" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\SearchSettings" /v "IsMSACloudSearchEnabled" /f >nul 2>&1

:: Reset search box display
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Search" /v "SearchboxTaskbarMode" /t REG_DWORD /d "1" /f >nul 2>&1

:: Clear search history
call :log_message "INFO" "Clearing search history..."
call :clear_folder "%LOCALAPPDATA%\Microsoft\Windows\History" "Search History"
call :clear_folder "%LOCALAPPDATA%\Packages\Microsoft.Windows.Cortana_cw5n1h2txyewy\LocalState" "Cortana Data"

:: Reset file indexing options
call :log_message "INFO" "Resetting file indexing options..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\DefaultRules" /f >nul 2>&1

:: Add default indexed locations
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\DefaultRules" /v "{Users}" /t REG_DWORD /d "1" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\CrawlScopeManager\Windows\SystemIndex\DefaultRules" /v "{StartMenu}" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset indexer performance settings
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows Search\Gathering Manager" /v "DisableBackOff" /t REG_DWORD /d "1" /f >nul 2>&1

:: Start Windows Search service
call :log_message "INFO" "Starting Windows Search service..."
net start wsearch >nul 2>&1

:: Rebuild search index
call :log_message "INFO" "Rebuilding search index..."
powershell -command "& {Get-WmiObject -Class Win32_Volume | ForEach-Object {$indexer = Get-WmiObject -Class CIM_DataFile -Filter \"Name='$($_.DriveLetter)\\*'\"}}" >nul 2>&1

call :log_message "SUCCESS" "Windows Search Reset completed"
echo.
echo Windows Search has been reset and index rebuild started.
echo The search index will be rebuilt in the background.
echo This process may take several hours depending on your data.
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

call :log_message "INFO" "Windows Search Reset completed"
exit /b 0