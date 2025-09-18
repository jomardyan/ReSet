@echo off
:: Windows Settings Reset Toolkit - Utility Functions
:: Common functions for logging, backup, and safety checks

:: Initialize variables
if not defined RESET_ROOT set RESET_ROOT=%~dp0..
if not defined LOG_DIR set LOG_DIR=%RESET_ROOT%\logs
if not defined BACKUP_DIR set BACKUP_DIR=%RESET_ROOT%\backups

:: Create log directory if it doesn't exist
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Create backup directory if it doesn't exist
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: Set log file with current date
for /f "tokens=2 delims==" %%i in ('wmic OS Get localdatetime /value') do set "dt=%%i"
set "YYYY=%dt:~0,4%"
set "MM=%dt:~4,2%"
set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%"
set "Min=%dt:~10,2%"
set "Sec=%dt:~12,2%"
set "LOG_FILE=%LOG_DIR%\reset-operations-%YYYY%-%MM%-%DD%.log"

:: Check if running as administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :admin_ok
) else (
    echo ERROR: This script must be run as Administrator.
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)
:admin_ok

:: Function to log messages
:log_message
set "LEVEL=%~1"
set "MESSAGE=%~2"
echo [%date% %time%] [%LEVEL%] %MESSAGE% >> "%LOG_FILE%"

:: Color coding for different log levels
if /i "%LEVEL%"=="ERROR" (
    echo [91m[%LEVEL%] %MESSAGE%[0m
) else if /i "%LEVEL%"=="SUCCESS" (
    echo [92m[%LEVEL%] %MESSAGE%[0m
) else if /i "%LEVEL%"=="WARN" (
    echo [93m[%LEVEL%] %MESSAGE%[0m
) else if /i "%LEVEL%"=="INFO" (
    echo [94m[%LEVEL%] %MESSAGE%[0m
) else (
    echo [%LEVEL%] %MESSAGE%
)
goto :eof

:: Function to show progress
:show_progress
set "current=%~1"
set "total=%~2"
set "operation=%~3"

set /a percent=(%current%*100)/%total%
set "progress_bar="

:: Create progress bar (20 characters)
set /a bars=%percent%/5
for /l %%i in (1,1,%bars%) do set "progress_bar=!progress_bar!█"
for /l %%i in (%bars%,1,19) do set "progress_bar=!progress_bar!░"

echo [96m[%percent%%%] [%progress_bar%] %operation%[0m
goto :eof

:: Function to create backup
:create_backup
set "BACKUP_NAME=%~1"
set "SOURCE_PATH=%~2"
set "BACKUP_PATH=%BACKUP_DIR%\%BACKUP_NAME%_%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%"

call :log_message "INFO" "Creating backup: %BACKUP_NAME%"

if exist "%SOURCE_PATH%" (
    if exist "%SOURCE_PATH%\*" (
        :: Directory backup
        xcopy "%SOURCE_PATH%" "%BACKUP_PATH%" /e /i /y >nul 2>&1
    ) else (
        :: File backup
        if not exist "%BACKUP_PATH%" mkdir "%BACKUP_PATH%"
        copy "%SOURCE_PATH%" "%BACKUP_PATH%\" >nul 2>&1
    )
    
    if %errorlevel% == 0 (
        call :log_message "SUCCESS" "Backup created successfully: %BACKUP_PATH%"
        set "LAST_BACKUP=%BACKUP_PATH%"
    ) else (
        call :log_message "ERROR" "Failed to create backup: %BACKUP_NAME%"
        if /i not "%SILENT_MODE%"=="true" (
            echo.
            echo WARNING: Backup creation failed!
            set /p "CONTINUE_WITHOUT_BACKUP=Continue without backup? (y/N): "
            if /i not "!CONTINUE_WITHOUT_BACKUP!"=="y" (
                echo Operation cancelled for safety.
                exit /b 1
            )
        ) else (
            echo ERROR: Cannot continue in silent mode without backup capability
            exit /b 1
        )
    )
) else (
    call :log_message "WARN" "Source path does not exist: %SOURCE_PATH%"
)
goto :eof

:: Enhanced function to create registry backup with verification
:backup_registry
set "REG_KEY=%~1"
set "BACKUP_NAME=%~2"
set "REG_BACKUP_FILE=%BACKUP_DIR%\%BACKUP_NAME%_%YYYY%-%MM%-%DD%_%HH%-%Min%-%Sec%.reg"

call :log_message "INFO" "Backing up registry key: %REG_KEY%"
reg export "%REG_KEY%" "%REG_BACKUP_FILE%" /y >nul 2>&1

if %errorlevel% == 0 (
    :: Verify backup file is valid
    findstr /m "Windows Registry Editor" "%REG_BACKUP_FILE%" >nul 2>&1
    if !errorlevel! == 0 (
        call :log_message "SUCCESS" "Registry backup created and verified: %REG_BACKUP_FILE%"
        set "LAST_BACKUP=%REG_BACKUP_FILE%"
    ) else (
        call :log_message "ERROR" "Registry backup file appears corrupted"
        del "%REG_BACKUP_FILE%" >nul 2>&1
        exit /b 1
    )
) else (
    call :log_message "ERROR" "Failed to backup registry key: %REG_KEY%"
    exit /b 1
)
goto :eof

:: Enhanced confirmation function with better safety
:confirm_action
set "ACTION=%~1"
if /i "%SILENT_MODE%"=="true" goto :confirmed

echo.
echo [93m============================================[0m
echo [93m                WARNING[0m  
echo [93m============================================[0m
echo.
echo This operation will: %ACTION%
echo.
echo [91mIMPORTANT:[0m This action cannot be easily undone without backups.
echo Make sure you have:
echo  • Created a system restore point
echo  • Backed up important data
echo  • Closed all applications
echo.
echo [96mBackups will be created automatically before changes.[0m
echo.
set /p "CONFIRM=Do you want to continue? (yes/NO): "
if /i "%CONFIRM%"=="yes" goto :confirmed
if /i "%CONFIRM%"=="y" (
    echo.
    echo [93mPlease type "yes" (not just "y") to confirm this operation.[0m
    set /p "CONFIRM2=Type 'yes' to continue: "
    if /i "!CONFIRM2!"=="yes" goto :confirmed
)

call :log_message "INFO" "Operation cancelled by user"
echo [93mOperation cancelled.[0m
exit /b 1

:confirmed
call :log_message "INFO" "User confirmed operation: %ACTION%"
goto :eof

:: Function to check Windows version
:check_windows_version
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
if "%VERSION%" == "10.0" (
    call :log_message "INFO" "Windows 10/11 detected"
) else (
    call :log_message "WARN" "This script is designed for Windows 10/11. Current version: %VERSION%"
)
goto :eof

:: Function to restart required services
:restart_service
set "SERVICE_NAME=%~1"
call :log_message "INFO" "Restarting service: %SERVICE_NAME%"

net stop "%SERVICE_NAME%" >nul 2>&1
timeout /t 2 /nobreak >nul
net start "%SERVICE_NAME%" >nul 2>&1

if %errorlevel% == 0 (
    call :log_message "SUCCESS" "Service restarted: %SERVICE_NAME%"
) else (
    call :log_message "WARN" "Failed to restart service: %SERVICE_NAME%"
)
goto :eof

:: Function to kill process safely
:kill_process
set "PROCESS_NAME=%~1"
call :log_message "INFO" "Stopping process: %PROCESS_NAME%"

taskkill /f /im "%PROCESS_NAME%" >nul 2>&1
if %errorlevel% == 0 (
    call :log_message "SUCCESS" "Process stopped: %PROCESS_NAME%"
) else (
    call :log_message "INFO" "Process not running or already stopped: %PROCESS_NAME%"
)
goto :eof

:: Function to clear specific folder
:clear_folder
set "FOLDER_PATH=%~1"
set "FOLDER_NAME=%~2"

if exist "%FOLDER_PATH%" (
    call :log_message "INFO" "Clearing folder: %FOLDER_NAME%"
    del /q /s "%FOLDER_PATH%\*" >nul 2>&1
    for /d %%x in ("%FOLDER_PATH%\*") do rd /s /q "%%x" >nul 2>&1
    
    if %errorlevel% == 0 (
        call :log_message "SUCCESS" "Folder cleared: %FOLDER_NAME%"
    ) else (
        call :log_message "WARN" "Some files could not be deleted in: %FOLDER_NAME%"
    )
) else (
    call :log_message "INFO" "Folder does not exist: %FOLDER_NAME%"
)
goto :eof

:: Parse command line arguments
:parse_args
if "%~1"=="" goto :eof
if /i "%~1"=="--silent" set "SILENT_MODE=true"
if /i "%~1"=="--verify-backup" set "VERIFY_BACKUP=true"
if /i "%~1"=="--backup-path" (
    set "BACKUP_DIR=%~2"
    shift
)
shift
goto :parse_args