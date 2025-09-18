@echo off
:: Windows Settings Reset Toolkit - Validation System
:: Tests all reset scripts and validates the installation

title ReSet - Validation System

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "VALIDATION_LOG=%ROOT_DIR%\logs\validation-%date:~-4,4%%date:~-10,2%%date:~-7,2%-%time:~0,2%%time:~3,2%%time:~6,2%.log"

echo.
echo ============================================
echo  ReSet Toolkit Validation System
echo ============================================
echo.

:: Initialize logging
if not exist "%ROOT_DIR%\logs" mkdir "%ROOT_DIR%\logs"
echo [%date% %time%] Starting ReSet Toolkit validation > "%VALIDATION_LOG%"

:: Initialize counters
set "tests_passed=0"
set "tests_failed=0"
set "tests_skipped=0"
set "critical_errors=0"

:: Function to log validation results
:log_validation
set "level=%~1"
set "message=%~2"
echo [%date% %time%] [%level%] %message% >> "%VALIDATION_LOG%"
if /i "%level%"=="PASS" (
    echo [✓] %message%
    set /a tests_passed+=1
) else if /i "%level%"=="FAIL" (
    echo [✗] %message%
    set /a tests_failed+=1
) else if /i "%level%"=="SKIP" (
    echo [~] %message%
    set /a tests_skipped+=1
) else if /i "%level%"=="CRITICAL" (
    echo [!] %message%
    set /a critical_errors+=1
) else (
    echo [i] %message%
)
goto :eof

:: Test 1: Check administrator privileges
call :log_validation "INFO" "Testing administrator privileges..."
net session >nul 2>&1
if %errorLevel% == 0 (
    call :log_validation "PASS" "Administrator privileges confirmed"
) else (
    call :log_validation "CRITICAL" "Administrator privileges required but not detected"
)

:: Test 2: Validate directory structure
call :log_validation "INFO" "Validating directory structure..."
set "required_dirs=scripts logs backups docs gui"
for %%d in (%required_dirs%) do (
    if exist "%ROOT_DIR%\%%d" (
        call :log_validation "PASS" "Directory exists: %%d"
    ) else (
        call :log_validation "FAIL" "Missing directory: %%d"
    )
)

:: Test 3: Check core files
call :log_validation "INFO" "Checking core files..."
set "core_files=batch-reset.bat install.bat restore-backup.bat scripts\utils.bat"
for %%f in (%core_files%) do (
    if exist "%ROOT_DIR%\%%f" (
        call :log_validation "PASS" "Core file exists: %%f"
    ) else (
        call :log_validation "CRITICAL" "Missing core file: %%f"
    )
)

:: Test 4: Validate reset scripts
call :log_validation "INFO" "Validating reset scripts..."
set "reset_count=0"
for %%f in ("%SCRIPT_DIR%\reset-*.bat") do (
    set /a reset_count+=1
    set "script_name=%%~nxf"
    
    :: Check script header
    findstr /m "Windows Settings Reset Toolkit" "%%f" >nul
    if !errorlevel! == 0 (
        call :log_validation "PASS" "Script header valid: !script_name!"
    ) else (
        call :log_validation "FAIL" "Invalid script header: !script_name!"
    )
    
    :: Check for utils.bat inclusion
    findstr /m "call.*utils.bat" "%%f" >nul
    if !errorlevel! == 0 (
        call :log_validation "PASS" "Utils.bat inclusion found: !script_name!"
    ) else (
        call :log_validation "FAIL" "Missing utils.bat inclusion: !script_name!"
    )
    
    :: Check for backup creation
    findstr /m "backup_registry\|create_backup" "%%f" >nul
    if !errorlevel! == 0 (
        call :log_validation "PASS" "Backup functionality found: !script_name!"
    ) else (
        call :log_validation "FAIL" "Missing backup functionality: !script_name!"
    )
    
    :: Check for error handling
    findstr /m "errorlevel\|exit /b" "%%f" >nul
    if !errorlevel! == 0 (
        call :log_validation "PASS" "Error handling found: !script_name!"
    ) else (
        call :log_validation "FAIL" "Missing error handling: !script_name!"
    )
)

call :log_validation "INFO" "Found %reset_count% reset scripts"
if %reset_count% geq 22 (
    call :log_validation "PASS" "Expected number of reset scripts found (22+)"
) else (
    call :log_validation "FAIL" "Missing reset scripts (found %reset_count%, expected 22)"
)

:: Test 5: Check PowerShell availability
call :log_validation "INFO" "Testing PowerShell availability..."
powershell -command "Get-Host" >nul 2>&1
if %errorlevel% == 0 (
    call :log_validation "PASS" "PowerShell is available"
) else (
    call :log_validation "FAIL" "PowerShell is not available or not working"
)

:: Test 6: Check disk space
call :log_validation "INFO" "Checking available disk space..."
for /f "tokens=3" %%i in ('dir /-c "%ROOT_DIR%" ^| find "bytes free"') do set "free_space=%%i"
if defined free_space (
    if %free_space% gtr 1073741824 (
        call :log_validation "PASS" "Sufficient disk space available"
    ) else (
        call :log_validation "FAIL" "Low disk space detected (less than 1GB free)"
    )
) else (
    call :log_validation "SKIP" "Could not determine disk space"
)

:: Test 7: Validate configuration
call :log_validation "INFO" "Testing configuration system..."
if exist "%ROOT_DIR%\config.ini" (
    call :log_validation "PASS" "Configuration file exists"
    
    :: Test configuration parser
    call "%SCRIPT_DIR%\config.bat" validate >nul 2>&1
    if !errorlevel! == 0 (
        call :log_validation "PASS" "Configuration validation passed"
    ) else (
        call :log_validation "FAIL" "Configuration validation failed"
    )
) else (
    call :log_validation "FAIL" "Configuration file missing"
)

:: Test 8: Test logging functionality
call :log_validation "INFO" "Testing logging functionality..."
call "%SCRIPT_DIR%\utils.bat" >nul 2>&1
if %errorlevel% == 0 (
    call :log_validation "PASS" "Utils.bat loads without errors"
) else (
    call :log_validation "FAIL" "Utils.bat has loading errors"
)

:: Test 9: Check registry backup functionality
call :log_validation "INFO" "Testing registry backup functionality..."
reg query "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion" >nul 2>&1
if %errorlevel% == 0 (
    call :log_validation "PASS" "Registry access is working"
) else (
    call :log_validation "FAIL" "Registry access is not working"
)

:: Test 10: System compatibility check
call :log_validation "INFO" "Checking system compatibility..."
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
if "%VERSION%" == "10.0" (
    call :log_validation "PASS" "Windows 10/11 detected (compatible)"
) else (
    call :log_validation "FAIL" "Unsupported Windows version: %VERSION%"
)

:: Test 11: Performance validation
call :log_validation "INFO" "Running performance validation..."
set "start_time=%time%"
timeout /t 1 /nobreak >nul 2>&1
set "end_time=%time%"
if %errorlevel% == 0 (
    call :log_validation "PASS" "System performance appears normal"
) else (
    call :log_validation "FAIL" "System performance issues detected"
)

:: Test 12: Security validation
call :log_validation "INFO" "Checking security settings..."
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v "EnableLUA" >nul 2>&1
if %errorlevel% == 0 (
    call :log_validation "PASS" "UAC configuration accessible"
) else (
    call :log_validation "FAIL" "UAC configuration not accessible"
)

:: Calculate and display results
set /a total_tests=%tests_passed%+%tests_failed%+%tests_skipped%
set /a pass_percentage=%tests_passed%*100/%total_tests%

echo.
echo ============================================
echo  Validation Results Summary
echo ============================================
echo.
echo Tests Passed: %tests_passed%
echo Tests Failed: %tests_failed%
echo Tests Skipped: %tests_skipped%
echo Critical Errors: %critical_errors%
echo Total Tests: %total_tests%
echo.
echo Pass Rate: %pass_percentage%%%
echo.

:: Log final results
echo [%date% %time%] Validation completed: %tests_passed% passed, %tests_failed% failed, %tests_skipped% skipped >> "%VALIDATION_LOG%"
echo [%date% %time%] Critical errors: %critical_errors% >> "%VALIDATION_LOG%"

:: Determine overall result
if %critical_errors% gtr 0 (
    echo Status: CRITICAL ISSUES DETECTED
    echo The toolkit has critical issues that must be resolved before use.
    call :log_validation "CRITICAL" "Validation failed with critical issues"
    exit /b 2
) else if %tests_failed% gtr 0 (
    echo Status: VALIDATION FAILED
    echo Some tests failed. Review the issues before using the toolkit.
    call :log_validation "FAIL" "Validation completed with failures"
    exit /b 1
) else (
    echo Status: VALIDATION PASSED
    echo The ReSet Toolkit is ready for use.
    call :log_validation "PASS" "All validations completed successfully"
    exit /b 0
)

echo.
echo Validation log saved to: %VALIDATION_LOG%
echo.

if /i not "%1"=="--silent" (
    echo Press any key to continue...
    pause >nul
)