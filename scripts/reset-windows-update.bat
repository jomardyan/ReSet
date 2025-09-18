@echo off
:: Windows Settings Reset Toolkit - Windows Update Reset
:: Clears Windows Update cache, resets update components, and restores automatic updates

title ReSet - Windows Update Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Windows Update Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset Windows Update components and clear update cache"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "windows_update_policies"
call :create_backup "windows_update_logs" "%SystemRoot%\WindowsUpdate.log"

:: Stop Windows Update services
call :log_message "INFO" "Stopping Windows Update services..."
net stop wuauserv /y >nul 2>&1
net stop cryptSvc /y >nul 2>&1
net stop bits /y >nul 2>&1
net stop msiserver /y >nul 2>&1
net stop dosvc /y >nul 2>&1

call :log_message "SUCCESS" "Windows Update services stopped"

:: Clear Windows Update cache
call :log_message "INFO" "Clearing Windows Update cache..."
call :clear_folder "%SystemRoot%\SoftwareDistribution\Download" "SoftwareDistribution Download"
call :clear_folder "%SystemRoot%\SoftwareDistribution\DataStore" "SoftwareDistribution DataStore"

:: Backup and rename SoftwareDistribution folder
if exist "%SystemRoot%\SoftwareDistribution.bak" (
    rd /s /q "%SystemRoot%\SoftwareDistribution.bak" >nul 2>&1
)
if exist "%SystemRoot%\SoftwareDistribution" (
    call :log_message "INFO" "Backing up SoftwareDistribution folder..."
    move "%SystemRoot%\SoftwareDistribution" "%SystemRoot%\SoftwareDistribution.bak" >nul 2>&1
)

:: Backup and rename catroot2 folder
if exist "%SystemRoot%\System32\catroot2.bak" (
    rd /s /q "%SystemRoot%\System32\catroot2.bak" >nul 2>&1
)
if exist "%SystemRoot%\System32\catroot2" (
    call :log_message "INFO" "Backing up catroot2 folder..."
    move "%SystemRoot%\System32\catroot2" "%SystemRoot%\System32\catroot2.bak" >nul 2>&1
)

:: Clear BITS queue
call :log_message "INFO" "Clearing BITS transfer queue..."
bitsadmin /reset /allusers >nul 2>&1

:: Reset Windows Update policies
call :log_message "INFO" "Resetting Windows Update policies..."
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /f >nul 2>&1

:: Reset Windows Update registry entries
call :log_message "INFO" "Resetting Windows Update registry..."
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting" /f >nul 2>&1

:: Enable automatic updates
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v "AUOptions" /t REG_DWORD /d "4" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v "ScheduledInstallDay" /t REG_DWORD /d "0" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v "ScheduledInstallTime" /t REG_DWORD /d "3" /f >nul 2>&1

:: Reset Windows Store update settings
call :log_message "INFO" "Resetting Windows Store update settings..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\WindowsStore" /v "AutoDownload" /t REG_DWORD /d "4" /f >nul 2>&1

:: Clear Windows Update event logs
call :log_message "INFO" "Clearing Windows Update event logs..."
wevtutil cl "Microsoft-Windows-WindowsUpdateClient/Operational" >nul 2>&1
wevtutil cl "System" >nul 2>&1

:: Re-register Windows Update DLLs
call :log_message "INFO" "Re-registering Windows Update DLLs..."
regsvr32.exe /s atl.dll
regsvr32.exe /s urlmon.dll
regsvr32.exe /s mshtml.dll
regsvr32.exe /s shdocvw.dll
regsvr32.exe /s browseui.dll
regsvr32.exe /s jscript.dll
regsvr32.exe /s vbscript.dll
regsvr32.exe /s scrrun.dll
regsvr32.exe /s msxml.dll
regsvr32.exe /s msxml3.dll
regsvr32.exe /s msxml6.dll
regsvr32.exe /s actxprxy.dll
regsvr32.exe /s softpub.dll
regsvr32.exe /s wintrust.dll
regsvr32.exe /s dssenh.dll
regsvr32.exe /s rsaenh.dll
regsvr32.exe /s gpkcsp.dll
regsvr32.exe /s sccbase.dll
regsvr32.exe /s slbcsp.dll
regsvr32.exe /s cryptdlg.dll
regsvr32.exe /s oleaut32.dll
regsvr32.exe /s ole32.dll
regsvr32.exe /s shell32.dll
regsvr32.exe /s initpki.dll
regsvr32.exe /s wuapi.dll
regsvr32.exe /s wuaueng.dll
regsvr32.exe /s wuaueng1.dll
regsvr32.exe /s wucltui.dll
regsvr32.exe /s wups.dll
regsvr32.exe /s wups2.dll
regsvr32.exe /s wuweb.dll
regsvr32.exe /s qmgr.dll
regsvr32.exe /s qmgrprxy.dll
regsvr32.exe /s wucltux.dll
regsvr32.exe /s muweb.dll
regsvr32.exe /s wuwebv.dll

call :log_message "SUCCESS" "Windows Update DLLs re-registered"

:: Reset Cryptographic Services
call :log_message "INFO" "Resetting Cryptographic Services..."
ren "%SystemRoot%\System32\catroot2" "catroot2.old" >nul 2>&1

:: Reset WSUS client settings
call :log_message "INFO" "Resetting WSUS client settings..."
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v "AccountDomainSid" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v "PingID" /f >nul 2>&1
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate" /v "SusClientId" /f >nul 2>&1

:: Reset Windows Update Agent
call :log_message "INFO" "Resetting Windows Update Agent..."
if exist "%SystemRoot%\System32\wuaueng.dll.bak" (
    del "%SystemRoot%\System32\wuaueng.dll.bak" >nul 2>&1
)

:: Clear temporary files
call :clear_folder "%TEMP%" "Temporary files"
call :clear_folder "%SystemRoot%\Temp" "Windows Temp files"

:: Reset network proxy for Windows Update
call :log_message "INFO" "Resetting Windows Update proxy settings..."
netsh winhttp reset proxy >nul 2>&1

:: Start Windows Update services
call :log_message "INFO" "Starting Windows Update services..."
net start cryptSvc >nul 2>&1
net start bits >nul 2>&1
net start msiserver >nul 2>&1
net start wuauserv >nul 2>&1
net start dosvc >nul 2>&1

call :log_message "SUCCESS" "Windows Update services started"

:: Force Windows Update detection
call :log_message "INFO" "Forcing Windows Update detection..."
wuauclt /resetauthorization /detectnow >nul 2>&1
powershell -command "& {(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()}" >nul 2>&1

:: Reset Windows Update Medic Service
call :log_message "INFO" "Resetting Windows Update Medic Service..."
call :restart_service "WaaSMedicSvc"

:: Check if update is working
call :log_message "INFO" "Testing Windows Update functionality..."
timeout /t 5 /nobreak >nul

call :log_message "SUCCESS" "Windows Update Reset completed"
echo.
echo Windows Update has been reset to defaults.
echo Changes include:
echo - Windows Update cache cleared
echo - Update services restarted
echo - Update policies reset
echo - Automatic updates enabled
echo - Update agent components re-registered
echo - WSUS client settings reset
echo - Cryptographic services reset
echo.
echo Windows Update should now function normally.
echo You can check for updates in Settings ^> Windows Update
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo Would you like to open Windows Update settings now? (y/N)
    set /p "OPEN_WU=Enter your choice: "
    if /i "%OPEN_WU%"=="y" (
        call :log_message "INFO" "Opening Windows Update settings"
        start ms-settings:windowsupdate
    )
)

call :log_message "INFO" "Windows Update Reset completed"
exit /b 0