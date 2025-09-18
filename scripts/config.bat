@echo off
:: Windows Settings Reset Toolkit - Configuration Manager
:: Handles reading and writing configuration settings

setlocal enabledelayedexpansion

:: Set default config file location
if not defined CONFIG_FILE set CONFIG_FILE=%~dp0..\config.ini

:: Initialize default values
set "LOG_LEVEL=INFO"
set "LOG_RETENTION_DAYS=30"
set "BACKUP_RETENTION_DAYS=30"
set "CREATE_BACKUPS=true"
set "CREATE_RESTORE_POINT=true"
set "REQUIRE_CONFIRMATION=true"
set "SILENT_MODE=false"
set "VERIFY_BACKUPS=true"
set "SAFE_MODE_ENABLED=true"
set "PARALLEL_EXECUTION=false"
set "MAX_CONCURRENT_OPERATIONS=3"
set "DELAY_BETWEEN_OPERATIONS=2"
set "LOG_DIRECTORY=logs"
set "BACKUP_DIRECTORY=backups"
set "SCRIPTS_DIRECTORY=scripts"

:: Function to read configuration
:read_config
if not exist "%CONFIG_FILE%" (
    echo [WARN] Configuration file not found: %CONFIG_FILE%
    echo [INFO] Using default configuration values
    goto :eof
)

echo [INFO] Loading configuration from: %CONFIG_FILE%

for /f "usebackq tokens=1,2 delims==" %%a in ("%CONFIG_FILE%") do (
    set "key=%%a"
    set "value=%%b"
    
    :: Skip comments and empty lines
    if not "!key:~0,1!"=="#" if not "!key!"=="" (
        :: Remove leading/trailing spaces
        for /f "tokens=* delims= " %%x in ("!key!") do set "key=%%x"
        for /f "tokens=* delims= " %%x in ("!value!") do set "value=%%x"
        
        :: Set configuration variables
        if /i "!key!"=="LogLevel" set "LOG_LEVEL=!value!"
        if /i "!key!"=="LogRetentionDays" set "LOG_RETENTION_DAYS=!value!"
        if /i "!key!"=="BackupRetentionDays" set "BACKUP_RETENTION_DAYS=!value!"
        if /i "!key!"=="CreateBackups" set "CREATE_BACKUPS=!value!"
        if /i "!key!"=="CreateRestorePoint" set "CREATE_RESTORE_POINT=!value!"
        if /i "!key!"=="RequireConfirmation" set "REQUIRE_CONFIRMATION=!value!"
        if /i "!key!"=="SilentMode" set "SILENT_MODE=!value!"
        if /i "!key!"=="VerifyBackups" set "VERIFY_BACKUPS=!value!"
        if /i "!key!"=="SafeModeEnabled" set "SAFE_MODE_ENABLED=!value!"
        if /i "!key!"=="ParallelExecution" set "PARALLEL_EXECUTION=!value!"
        if /i "!key!"=="MaxConcurrentOperations" set "MAX_CONCURRENT_OPERATIONS=!value!"
        if /i "!key!"=="DelayBetweenOperations" set "DELAY_BETWEEN_OPERATIONS=!value!"
        if /i "!key!"=="LogDirectory" set "LOG_DIRECTORY=!value!"
        if /i "!key!"=="BackupDirectory" set "BACKUP_DIRECTORY=!value!"
        if /i "!key!"=="ScriptsDirectory" set "SCRIPTS_DIRECTORY=!value!"
    )
)

echo [INFO] Configuration loaded successfully
goto :eof

:: Function to write configuration
:write_config
echo [INFO] Writing configuration to: %CONFIG_FILE%

echo # ReSet Toolkit Configuration File > "%CONFIG_FILE%"
echo # Generated on %date% %time% >> "%CONFIG_FILE%"
echo. >> "%CONFIG_FILE%"
echo [Settings] >> "%CONFIG_FILE%"
echo LogLevel=%LOG_LEVEL% >> "%CONFIG_FILE%"
echo LogRetentionDays=%LOG_RETENTION_DAYS% >> "%CONFIG_FILE%"
echo BackupRetentionDays=%BACKUP_RETENTION_DAYS% >> "%CONFIG_FILE%"
echo CreateBackups=%CREATE_BACKUPS% >> "%CONFIG_FILE%"
echo CreateRestorePoint=%CREATE_RESTORE_POINT% >> "%CONFIG_FILE%"
echo RequireConfirmation=%REQUIRE_CONFIRMATION% >> "%CONFIG_FILE%"
echo SilentMode=%SILENT_MODE% >> "%CONFIG_FILE%"
echo VerifyBackups=%VERIFY_BACKUPS% >> "%CONFIG_FILE%"
echo SafeModeEnabled=%SAFE_MODE_ENABLED% >> "%CONFIG_FILE%"
echo ParallelExecution=%PARALLEL_EXECUTION% >> "%CONFIG_FILE%"
echo MaxConcurrentOperations=%MAX_CONCURRENT_OPERATIONS% >> "%CONFIG_FILE%"
echo DelayBetweenOperations=%DELAY_BETWEEN_OPERATIONS% >> "%CONFIG_FILE%"
echo. >> "%CONFIG_FILE%"
echo [Paths] >> "%CONFIG_FILE%"
echo LogDirectory=%LOG_DIRECTORY% >> "%CONFIG_FILE%"
echo BackupDirectory=%BACKUP_DIRECTORY% >> "%CONFIG_FILE%"
echo ScriptsDirectory=%SCRIPTS_DIRECTORY% >> "%CONFIG_FILE%"

echo [INFO] Configuration saved successfully
goto :eof

:: Function to get configuration value
:get_config
set "config_key=%~1"
set "config_default=%~2"
set "config_result="

if /i "%config_key%"=="LogLevel" set "config_result=%LOG_LEVEL%"
if /i "%config_key%"=="LogRetentionDays" set "config_result=%LOG_RETENTION_DAYS%"
if /i "%config_key%"=="BackupRetentionDays" set "config_result=%BACKUP_RETENTION_DAYS%"
if /i "%config_key%"=="CreateBackups" set "config_result=%CREATE_BACKUPS%"
if /i "%config_key%"=="CreateRestorePoint" set "config_result=%CREATE_RESTORE_POINT%"
if /i "%config_key%"=="RequireConfirmation" set "config_result=%REQUIRE_CONFIRMATION%"
if /i "%config_key%"=="SilentMode" set "config_result=%SILENT_MODE%"
if /i "%config_key%"=="SafeModeEnabled" set "config_result=%SAFE_MODE_ENABLED%"

if "%config_result%"=="" set "config_result=%config_default%"
echo %config_result%
goto :eof

:: Function to set configuration value
:set_config
set "config_key=%~1"
set "config_value=%~2"

if /i "%config_key%"=="LogLevel" set "LOG_LEVEL=%config_value%"
if /i "%config_key%"=="LogRetentionDays" set "LOG_RETENTION_DAYS=%config_value%"
if /i "%config_key%"=="BackupRetentionDays" set "BACKUP_RETENTION_DAYS=%config_value%"
if /i "%config_key%"=="CreateBackups" set "CREATE_BACKUPS=%config_value%"
if /i "%config_key%"=="CreateRestorePoint" set "CREATE_RESTORE_POINT=%config_value%"
if /i "%config_key%"=="RequireConfirmation" set "REQUIRE_CONFIRMATION=%config_value%"
if /i "%config_key%"=="SilentMode" set "SILENT_MODE=%config_value%"
if /i "%config_key%"=="SafeModeEnabled" set "SAFE_MODE_ENABLED=%config_value%"

goto :eof

:: Function to validate configuration
:validate_config
set "validation_errors=0"

:: Validate numeric values
if %LOG_RETENTION_DAYS% lss 1 (
    echo [ERROR] LogRetentionDays must be greater than 0
    set /a validation_errors+=1
)

if %BACKUP_RETENTION_DAYS% lss 1 (
    echo [ERROR] BackupRetentionDays must be greater than 0
    set /a validation_errors+=1
)

if %MAX_CONCURRENT_OPERATIONS% lss 1 (
    echo [ERROR] MaxConcurrentOperations must be greater than 0
    set /a validation_errors+=1
)

:: Validate boolean values
if /i not "%CREATE_BACKUPS%"=="true" if /i not "%CREATE_BACKUPS%"=="false" (
    echo [ERROR] CreateBackups must be true or false
    set /a validation_errors+=1
)

if %validation_errors% gtr 0 (
    echo [ERROR] Configuration validation failed with %validation_errors% errors
    exit /b 1
) else (
    echo [INFO] Configuration validation passed
    exit /b 0
)

:: Function to show current configuration
:show_config
echo.
echo =========================================
echo  ReSet Toolkit Configuration
echo =========================================
echo.
echo [Settings]
echo LogLevel: %LOG_LEVEL%
echo LogRetentionDays: %LOG_RETENTION_DAYS%
echo BackupRetentionDays: %BACKUP_RETENTION_DAYS%
echo CreateBackups: %CREATE_BACKUPS%
echo CreateRestorePoint: %CREATE_RESTORE_POINT%
echo RequireConfirmation: %REQUIRE_CONFIRMATION%
echo SilentMode: %SILENT_MODE%
echo SafeModeEnabled: %SAFE_MODE_ENABLED%
echo.
echo [Paths]
echo LogDirectory: %LOG_DIRECTORY%
echo BackupDirectory: %BACKUP_DIRECTORY%
echo ScriptsDirectory: %SCRIPTS_DIRECTORY%
echo.
echo Configuration file: %CONFIG_FILE%
echo.
goto :eof

:: Main execution
if "%~1"=="read" call :read_config
if "%~1"=="write" call :write_config
if "%~1"=="show" call :show_config
if "%~1"=="validate" call :validate_config
if "%~1"=="get" call :get_config "%~2" "%~3"
if "%~1"=="set" call :set_config "%~2" "%~3"

if "%~1"=="" (
    echo Usage: config.bat [read^|write^|show^|validate^|get^|set]
    echo.
    echo Commands:
    echo   read       - Load configuration from file
    echo   write      - Save current configuration to file
    echo   show       - Display current configuration
    echo   validate   - Validate configuration values
    echo   get ^<key^>  - Get configuration value
    echo   set ^<key^> ^<value^> - Set configuration value
)