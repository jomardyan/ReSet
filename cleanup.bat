@echo off
:: Windows Settings Reset Toolkit - Cleanup System
:: Automatically cleans old backups, logs, and temporary files

title ReSet - Cleanup System

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."

:: Load configuration
call "%SCRIPT_DIR%\config.bat" read 2>nul

:: Set default retention periods if not configured
if not defined LOG_RETENTION_DAYS set LOG_RETENTION_DAYS=30
if not defined BACKUP_RETENTION_DAYS set BACKUP_RETENTION_DAYS=30

:: Initialize counters
set "files_deleted=0"
set "space_freed=0"
set "errors=0"

echo.
echo ============================================
echo  ReSet Toolkit Cleanup System
echo ============================================
echo.
echo Cleanup Configuration:
echo - Log retention: %LOG_RETENTION_DAYS% days
echo - Backup retention: %BACKUP_RETENTION_DAYS% days
echo.

:: Function to log cleanup operations
:log_cleanup
set "level=%~1"
set "message=%~2"
echo [%level%] %message%
if exist "%ROOT_DIR%\logs\cleanup.log" (
    echo [%date% %time%] [%level%] %message% >> "%ROOT_DIR%\logs\cleanup.log"
)
goto :eof

:: Function to calculate file age in days
:get_file_age
set "file_path=%~1"
set "file_age=0"

for %%f in ("%file_path%") do (
    set "file_date=%%~tf"
    :: Basic age calculation (simplified)
    for /f "tokens=1-3 delims=/" %%a in ("!file_date!") do (
        set "file_month=%%a"
        set "file_day=%%b"
        set "file_year=%%c"
    )
    
    :: Get current date
    for /f "tokens=1-3 delims=/" %%a in ("%date%") do (
        set "current_month=%%a"
        set "current_day=%%b"
        set "current_year=%%c"
    )
    
    :: Simplified age calculation (rough estimate)
    set /a "file_age=(!current_year!-!file_year!)*365+(!current_month!-!file_month!)*30+(!current_day!-!file_day!)"
    if !file_age! lss 0 set "file_age=0"
)

echo !file_age!
goto :eof

:: Function to delete old files
:cleanup_old_files
set "cleanup_dir=%~1"
set "retention_days=%~2"
set "file_pattern=%~3"
set "description=%~4"

if not exist "%cleanup_dir%" (
    call :log_cleanup "SKIP" "Directory does not exist: %cleanup_dir%"
    goto :eof
)

call :log_cleanup "INFO" "Cleaning %description% older than %retention_days% days..."

set "local_deleted=0"
for %%f in ("%cleanup_dir%\%file_pattern%") do (
    call :get_file_age "%%f"
    for /f %%a in ('call :get_file_age "%%f"') do set "age=%%a"
    
    if !age! gtr %retention_days% (
        set "file_size=0"
        for %%s in ("%%f") do set "file_size=%%~zs"
        
        del "%%f" >nul 2>&1
        if !errorlevel! == 0 (
            call :log_cleanup "SUCCESS" "Deleted: %%~nxf (age: !age! days, size: !file_size! bytes)"
            set /a local_deleted+=1
            set /a files_deleted+=1
            set /a space_freed+=!file_size!
        ) else (
            call :log_cleanup "ERROR" "Failed to delete: %%~nxf"
            set /a errors+=1
        )
    )
)

if !local_deleted! == 0 (
    call :log_cleanup "INFO" "No old %description% found to clean"
) else (
    call :log_cleanup "SUCCESS" "Cleaned !local_deleted! %description% files"
)
goto :eof

:: Function to clean empty directories
:cleanup_empty_dirs
set "cleanup_dir=%~1"
set "description=%~2"

if not exist "%cleanup_dir%" goto :eof

call :log_cleanup "INFO" "Checking for empty directories in %description%..."

for /d %%d in ("%cleanup_dir%\*") do (
    dir /b "%%d" 2>nul | findstr /r "." >nul
    if !errorlevel! neq 0 (
        rd "%%d" >nul 2>&1
        if !errorlevel! == 0 (
            call :log_cleanup "SUCCESS" "Removed empty directory: %%~nxd"
        ) else (
            call :log_cleanup "ERROR" "Failed to remove directory: %%~nxd"
            set /a errors+=1
        )
    )
)
goto :eof

:: Start cleanup operations
call :log_cleanup "INFO" "Starting automatic cleanup..."

:: Clean old log files
call :cleanup_old_files "%ROOT_DIR%\logs" "%LOG_RETENTION_DAYS%" "*.log" "log files"

:: Clean old backup files
call :cleanup_old_files "%ROOT_DIR%\backups" "%BACKUP_RETENTION_DAYS%" "*.*" "backup files"

:: Clean old registry backups
call :cleanup_old_files "%ROOT_DIR%\backups" "%BACKUP_RETENTION_DAYS%" "*.reg" "registry backup files"

:: Clean temporary files
if exist "%ROOT_DIR%\temp" (
    call :cleanup_old_files "%ROOT_DIR%\temp" "7" "*.*" "temporary files"
)

:: Clean Windows temp files created by ReSet
call :cleanup_old_files "%TEMP%" "1" "ReSet_*.*" "ReSet temporary files"

:: Clean old validation logs
call :cleanup_old_files "%ROOT_DIR%\logs" "14" "validation-*.log" "validation logs"

:: Clean old installation logs
call :cleanup_old_files "%ROOT_DIR%\logs" "30" "installation-*.log" "installation logs"

:: Clean empty directories
call :cleanup_empty_dirs "%ROOT_DIR%\backups" "backup directory"
call :cleanup_empty_dirs "%ROOT_DIR%\temp" "temp directory"

:: Clean up corrupted backup files
call :log_cleanup "INFO" "Checking for corrupted backup files..."
for %%f in ("%ROOT_DIR%\backups\*.reg") do (
    findstr /m "Windows Registry Editor" "%%f" >nul 2>&1
    if !errorlevel! neq 0 (
        del "%%f" >nul 2>&1
        if !errorlevel! == 0 (
            call :log_cleanup "SUCCESS" "Removed corrupted registry backup: %%~nxf"
            set /a files_deleted+=1
        )
    )
)

:: Optimize backup storage (compress old backups if enabled)
if exist "%ROOT_DIR%\config.ini" (
    findstr /i "BackupCompressionEnabled=true" "%ROOT_DIR%\config.ini" >nul 2>&1
    if !errorlevel! == 0 (
        call :log_cleanup "INFO" "Compressing old backup files..."
        
        for %%f in ("%ROOT_DIR%\backups\*") do (
            call :get_file_age "%%f"
            for /f %%a in ('call :get_file_age "%%f"') do set "age=%%a"
            
            if !age! gtr 7 (
                if not "%%~xf"==".zip" (
                    powershell -command "Compress-Archive -Path '%%f' -DestinationPath '%%f.zip' -Force" >nul 2>&1
                    if !errorlevel! == 0 (
                        del "%%f" >nul 2>&1
                        call :log_cleanup "SUCCESS" "Compressed backup: %%~nxf"
                    )
                )
            )
        )
    )
)

:: Calculate space freed in MB
set /a space_freed_mb=%space_freed%/1048576

:: Display results
echo.
echo ============================================
echo  Cleanup Results
echo ============================================
echo.
echo Files deleted: %files_deleted%
echo Space freed: %space_freed_mb% MB
echo Errors encountered: %errors%
echo.

call :log_cleanup "INFO" "Cleanup completed: %files_deleted% files deleted, %space_freed_mb% MB freed, %errors% errors"

:: Cleanup recommendations
if %files_deleted% == 0 (
    echo No cleanup was necessary - system is already clean.
) else if %files_deleted% lss 10 (
    echo Light cleanup performed - system maintenance is up to date.
) else (
    echo Significant cleanup performed - consider running cleanup more frequently.
)

if %errors% gtr 0 (
    echo.
    echo WARNING: %errors% errors occurred during cleanup.
    echo Check the cleanup log for details.
    exit /b 1
) else (
    echo.
    echo Cleanup completed successfully.
    exit /b 0
)

echo.
if /i not "%1"=="--silent" (
    echo Press any key to continue...
    pause >nul
)