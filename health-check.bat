@echo off
:: Windows Settings Reset Toolkit - System Health Checker
:: Analyzes system health and recommends appropriate reset operations

title ReSet - System Health Checker

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."

echo.
echo ============================================
echo  ReSet System Health Checker
echo ============================================
echo.

:: Initialize health scores
set "overall_health=100"
set "performance_health=100"
set "security_health=100"
set "stability_health=100"
set "storage_health=100"

:: Initialize recommendation lists
set "recommended_resets="
set "priority_resets="
set "optional_resets="

:: Function to log health check
:log_health
set "component=%~1"
set "status=%~2"
set "message=%~3"
set "impact=%~4"

if /i "%status%"=="GOOD" (
    echo [✓] %component%: %message%
) else if /i "%status%"=="WARNING" (
    echo [!] %component%: %message%
    set /a overall_health-=%impact%
) else if /i "%status%"=="CRITICAL" (
    echo [✗] %component%: %message%
    set /a overall_health-=%impact%
) else (
    echo [i] %component%: %message%
)
goto :eof

:: Function to add reset recommendation
:add_recommendation
set "script_name=%~1"
set "priority=%~2"
set "reason=%~3"

if /i "%priority%"=="HIGH" (
    if "%priority_resets%"=="" (
        set "priority_resets=%script_name%"
    ) else (
        set "priority_resets=%priority_resets%,%script_name%"
    )
) else if /i "%priority%"=="MEDIUM" (
    if "%recommended_resets%"=="" (
        set "recommended_resets=%script_name%"
    ) else (
        set "recommended_resets=%recommended_resets%,%script_name%"
    )
) else (
    if "%optional_resets%"=="" (
        set "optional_resets=%script_name%"
    ) else (
        set "optional_resets=%optional_resets%,%script_name%"
    )
)

echo    → Recommended: %script_name% (%priority% priority) - %reason%
goto :eof

echo Analyzing system health...
echo.

:: Check 1: System Performance
echo [1/12] Checking system performance...
wmic cpu get loadpercentage /value | findstr "LoadPercentage" >nul 2>&1
if %errorlevel% == 0 (
    for /f "tokens=2 delims==" %%i in ('wmic cpu get loadpercentage /value ^| findstr "LoadPercentage"') do set "cpu_load=%%i"
    if !cpu_load! gtr 80 (
        call :log_health "Performance" "WARNING" "High CPU usage detected (!cpu_load!%%)" 10
        call :add_recommendation "reset-performance" "MEDIUM" "High CPU usage may indicate performance issues"
        set /a performance_health-=20
    ) else (
        call :log_health "Performance" "GOOD" "CPU usage normal (!cpu_load!%%)" 0
    )
) else (
    call :log_health "Performance" "WARNING" "Could not check CPU performance" 5
)

:: Check 2: Memory Usage
echo [2/12] Checking memory usage...
for /f "tokens=2 delims==" %%i in ('wmic OS get TotalVisibleMemorySize /value') do set "total_memory=%%i"
for /f "tokens=2 delims==" %%i in ('wmic OS get FreePhysicalMemory /value') do set "free_memory=%%i"
if defined total_memory if defined free_memory (
    set /a memory_usage=(!total_memory!-!free_memory!)*100/!total_memory!
    if !memory_usage! gtr 85 (
        call :log_health "Memory" "WARNING" "High memory usage (!memory_usage!%%)" 10
        call :add_recommendation "reset-performance" "MEDIUM" "High memory usage detected"
        set /a performance_health-=15
    ) else (
        call :log_health "Memory" "GOOD" "Memory usage normal (!memory_usage!%%)" 0
    )
) else (
    call :log_health "Memory" "WARNING" "Could not check memory usage" 5
)

:: Check 3: Disk Space
echo [3/12] Checking disk space...
for /f "tokens=3" %%i in ('dir /-c %SystemDrive%\ ^| find "bytes free"') do set "free_space=%%i"
for /f "tokens=2" %%j in ('dir /-c %SystemDrive%\ ^| find "bytes free"') do set "total_space=%%j"
if defined free_space if defined total_space (
    set /a space_usage=(!total_space!-!free_space!)*100/!total_space!
    if !space_usage! gtr 90 (
        call :log_health "Storage" "CRITICAL" "Very low disk space (!space_usage!%% used)" 20
        call :add_recommendation "cleanup" "HIGH" "Critical disk space shortage"
        set /a storage_health-=30
    ) else if !space_usage! gtr 80 (
        call :log_health "Storage" "WARNING" "Low disk space (!space_usage!%% used)" 10
        call :add_recommendation "cleanup" "MEDIUM" "Low disk space detected"
        set /a storage_health-=15
    ) else (
        call :log_health "Storage" "GOOD" "Disk space adequate (!space_usage!%% used)" 0
    )
) else (
    call :log_health "Storage" "WARNING" "Could not check disk space" 5
)

:: Check 4: Windows Update Status
echo [4/12] Checking Windows Update status...
sc query wuauserv | findstr "RUNNING" >nul 2>&1
if %errorlevel% == 0 (
    call :log_health "Updates" "GOOD" "Windows Update service is running" 0
) else (
    call :log_health "Updates" "WARNING" "Windows Update service not running" 10
    call :add_recommendation "reset-windows-update" "MEDIUM" "Windows Update service issues detected"
    set /a stability_health-=15
)

:: Check 5: Windows Defender Status
echo [5/12] Checking Windows Defender status...
sc query windefend | findstr "RUNNING" >nul 2>&1
if %errorlevel__ == 0 (
    call :log_health "Security" "GOOD" "Windows Defender service is running" 0
) else (
    call :log_health "Security" "WARNING" "Windows Defender service not running" 15
    call :add_recommendation "reset-defender" "HIGH" "Windows Defender service issues"
    set /a security_health-=25
)

:: Check 6: Network Connectivity
echo [6/12] Checking network connectivity...
ping -n 1 8.8.8.8 >nul 2>&1
if %errorlevel% == 0 (
    call :log_health "Network" "GOOD" "Internet connectivity working" 0
) else (
    call :log_health "Network" "WARNING" "Internet connectivity issues" 15
    call :add_recommendation "reset-network" "HIGH" "Network connectivity problems"
    set /a stability_health-=20
)

:: Check 7: System File Integrity
echo [7/12] Checking system file integrity...
sfc /verifyonly >nul 2>&1
if %errorlevel% == 0 (
    call :log_health "System Files" "GOOD" "System files appear intact" 0
) else (
    call :log_health "System Files" "WARNING" "Potential system file issues" 15
    call :add_recommendation "reset-registry" "MEDIUM" "System file integrity concerns"
    set /a stability_health-=20
)

:: Check 8: Registry Health
echo [8/12] Checking registry health...
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion" >nul 2>&1
if %errorlevel% == 0 (
    call :log_health "Registry" "GOOD" "Registry access working" 0
) else (
    call :log_health "Registry" "CRITICAL" "Registry access issues" 25
    call :add_recommendation "reset-registry" "HIGH" "Critical registry problems"
    set /a stability_health-=30
)

:: Check 9: Display Settings
echo [9/12] Checking display settings...
powershell -command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width" >nul 2>&1
if %errorlevel% == 0 (
    call :log_health "Display" "GOOD" "Display system functioning" 0
) else (
    call :log_health "Display" "WARNING" "Display system issues" 10
    call :add_recommendation "reset-display" "LOW" "Display configuration problems"
)

:: Check 10: Audio System
echo [10/12] Checking audio system...
powershell -command "Get-WmiObject -Class Win32_SoundDevice" >nul 2>&1
if %errorlevel% == 0 (
    call :log_health "Audio" "GOOD" "Audio system functioning" 0
) else (
    call :log_health "Audio" "WARNING" "Audio system issues" 5
    call :add_recommendation "reset-audio" "LOW" "Audio configuration problems"
)

:: Check 11: Search Indexing
echo [11/12] Checking search indexing...
sc query wsearch | findstr "RUNNING" >nul 2>&1
if %errorlevel% == 0 (
    call :log_health "Search" "GOOD" "Search service running" 0
) else (
    call :log_health "Search" "WARNING" "Search service issues" 8
    call :add_recommendation "reset-search" "LOW" "Search indexing problems"
)

:: Check 12: Start Menu and Shell
echo [12/12] Checking Start Menu and shell...
tasklist | findstr "explorer.exe" >nul 2>&1
if %errorlevel% == 0 (
    call :log_health "Shell" "GOOD" "Windows shell running" 0
) else (
    call :log_health "Shell" "CRITICAL" "Windows shell not running" 20
    call :add_recommendation "reset-shell" "HIGH" "Critical shell problems"
    call :add_recommendation "reset-startmenu" "HIGH" "Start Menu issues"
    set /a stability_health-=25
)

:: Calculate component health scores
set /a performance_score=!performance_health!
set /a security_score=!security_health!
set /a stability_score=!stability_health!
set /a storage_score=!storage_health!

:: Display health summary
echo.
echo ============================================
echo  System Health Summary
echo ============================================
echo.
echo Overall Health Score: %overall_health%/100

if %overall_health% gtr 85 (
    echo Status: EXCELLENT - System is in great condition
) else if %overall_health% gtr 70 (
    echo Status: GOOD - Minor issues detected
) else if %overall_health% gtr 50 (
    echo Status: FAIR - Several issues need attention
) else (
    echo Status: POOR - System needs immediate attention
)

echo.
echo Component Health Scores:
echo - Performance: %performance_score%/100
echo - Security: %security_score%/100
echo - Stability: %stability_score%/100
echo - Storage: %storage_score%/100
echo.

:: Display recommendations
if not "%priority_resets%"=="" (
    echo ============================================
    echo  HIGH PRIORITY Recommendations
    echo ============================================
    echo.
    echo These issues should be addressed immediately:
    for %%r in (%priority_resets%) do (
        echo • Run: scripts\%%r.bat
    )
    echo.
    echo Batch command: batch-reset.bat --categories "%priority_resets%"
    echo.
)

if not "%recommended_resets%"=="" (
    echo ============================================
    echo  RECOMMENDED Actions
    echo ============================================
    echo.
    echo These issues should be addressed soon:
    for %%r in (%recommended_resets%) do (
        echo • Run: scripts\%%r.bat
    )
    echo.
    echo Batch command: batch-reset.bat --categories "%recommended_resets%"
    echo.
)

if not "%optional_resets%"=="" (
    echo ============================================
    echo  OPTIONAL Improvements
    echo ============================================
    echo.
    echo These may improve system performance:
    for %%r in (%optional_resets%) do (
        echo • Run: scripts\%%r.bat
    )
    echo.
)

if "%priority_resets%"=="" if "%recommended_resets%"=="" if "%optional_resets%"=="" (
    echo ============================================
    echo  No Issues Detected
    echo ============================================
    echo.
    echo Your system appears to be functioning well!
    echo No reset operations are currently recommended.
    echo.
)

:: Generate health report
set "HEALTH_REPORT=%ROOT_DIR%\logs\health-report-%date:~-4,4%%date:~-10,2%%date:~-7,2%.txt"
echo System Health Report - %date% %time% > "%HEALTH_REPORT%"
echo Overall Health Score: %overall_health%/100 >> "%HEALTH_REPORT%"
echo Performance: %performance_score%/100 >> "%HEALTH_REPORT%"
echo Security: %security_score%/100 >> "%HEALTH_REPORT%"
echo Stability: %stability_score%/100 >> "%HEALTH_REPORT%"
echo Storage: %storage_score%/100 >> "%HEALTH_REPORT%"
echo. >> "%HEALTH_REPORT%"
echo Priority Resets: %priority_resets% >> "%HEALTH_REPORT%"
echo Recommended Resets: %recommended_resets% >> "%HEALTH_REPORT%"
echo Optional Resets: %optional_resets% >> "%HEALTH_REPORT%"

echo Health report saved to: %HEALTH_REPORT%

:: Set exit code based on health score
if %overall_health% gtr 85 (
    exit /b 0
) else if %overall_health% gtr 50 (
    exit /b 1
) else (
    exit /b 2
)

echo.
if /i not "%1"=="--silent" (
    echo Press any key to continue...
    pause >nul
)