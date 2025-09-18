@echo off
:: Windows Settings Reset Toolkit - Network Adapter Reset
:: Resets TCP/IP stack, DNS settings, Windows Firewall, and network adapter configurations

title ReSet - Network Adapter Reset

:: Initialize
call "%~dp0utils.bat" %*
if errorlevel 1 exit /b 1

call :log_message "INFO" "Starting Network Adapter Reset"
call :check_windows_version

:: Confirm action
call :confirm_action "reset all network adapter settings and configurations"

:: Create backups
call :backup_registry "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "tcpip_parameters"
call :backup_registry "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" "internet_settings"

call :log_message "WARN" "Network connectivity will be temporarily lost during reset"
timeout /t 5 /nobreak >nul

:: Reset Winsock catalog
call :log_message "INFO" "Resetting Winsock catalog..."
netsh winsock reset >nul 2>&1
if %errorlevel% == 0 (
    call :log_message "SUCCESS" "Winsock catalog reset"
) else (
    call :log_message "ERROR" "Failed to reset Winsock catalog"
)

:: Reset TCP/IP stack
call :log_message "INFO" "Resetting TCP/IP stack..."
netsh int ip reset >nul 2>&1
if %errorlevel% == 0 (
    call :log_message "SUCCESS" "TCP/IP stack reset"
) else (
    call :log_message "ERROR" "Failed to reset TCP/IP stack"
)

:: Reset IPv6 configuration
call :log_message "INFO" "Resetting IPv6 configuration..."
netsh interface ipv6 reset >nul 2>&1
if %errorlevel% == 0 (
    call :log_message "SUCCESS" "IPv6 configuration reset"
) else (
    call :log_message "ERROR" "Failed to reset IPv6 configuration"
)

:: Reset network adapters to DHCP
call :log_message "INFO" "Resetting network adapters to DHCP..."
for /f "tokens=*" %%i in ('netsh interface show interface ^| findstr "Connected"') do (
    for /f "tokens=4*" %%a in ("%%i") do (
        set "ADAPTER_NAME=%%b"
        call :log_message "INFO" "Resetting adapter: !ADAPTER_NAME!"
        netsh interface ip set address "!ADAPTER_NAME!" dhcp >nul 2>&1
        netsh interface ip set dns "!ADAPTER_NAME!" dhcp >nul 2>&1
    )
)

:: Flush DNS cache
call :log_message "INFO" "Flushing DNS cache..."
ipconfig /flushdns >nul 2>&1
if %errorlevel% == 0 (
    call :log_message "SUCCESS" "DNS cache flushed"
) else (
    call :log_message "ERROR" "Failed to flush DNS cache"
)

:: Reset ARP cache
call :log_message "INFO" "Clearing ARP cache..."
arp -d * >nul 2>&1
if %errorlevel% == 0 (
    call :log_message "SUCCESS" "ARP cache cleared"
) else (
    call :log_message "WARN" "ARP cache clear returned warnings"
)

:: Reset NetBIOS cache
call :log_message "INFO" "Clearing NetBIOS cache..."
nbtstat -R >nul 2>&1
nbtstat -RR >nul 2>&1
if %errorlevel% == 0 (
    call :log_message "SUCCESS" "NetBIOS cache cleared"
) else (
    call :log_message "WARN" "NetBIOS cache clear returned warnings"
)

:: Reset Windows Firewall to defaults
call :log_message "INFO" "Resetting Windows Firewall..."
netsh advfirewall reset >nul 2>&1
if %errorlevel% == 0 (
    call :log_message "SUCCESS" "Windows Firewall reset to defaults"
) else (
    call :log_message "ERROR" "Failed to reset Windows Firewall"
)

:: Reset Internet Explorer/Edge proxy settings
call :log_message "INFO" "Resetting proxy settings..."
reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "ProxyEnable" /t REG_DWORD /d "0" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "ProxyServer" /f >nul 2>&1
reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" /v "ProxyOverride" /f >nul 2>&1

:: Reset network location to Public
call :log_message "INFO" "Setting network location to Public..."
powershell -command "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Public" >nul 2>&1

:: Reset network discovery
call :log_message "INFO" "Disabling network discovery..."
netsh advfirewall firewall set rule group="Network Discovery" new enable=No >nul 2>&1

:: Reset file and printer sharing
call :log_message "INFO" "Disabling file and printer sharing..."
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=No >nul 2>&1

:: Clear network credentials
call :log_message "INFO" "Clearing stored network credentials..."
cmdkey /list | findstr "Target:" | for /f "tokens=2" %%i in ('more') do cmdkey /delete:%%i >nul 2>&1

:: Reset network adapters order
call :log_message "INFO" "Resetting network adapter order..."
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Linkage" /v "Bind" /f >nul 2>&1

:: Reset network throttling
call :log_message "INFO" "Disabling network throttling..."
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d "ffffffff" /f >nul 2>&1

:: Reset SMB settings
call :log_message "INFO" "Resetting SMB settings..."
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters" /v "autodisconnecttimeout" /t REG_DWORD /d "15" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\lanmanserver\parameters" /v "Size" /t REG_DWORD /d "1" /f >nul 2>&1

:: Reset VPN connections
call :log_message "INFO" "Removing VPN connections..."
for /f "tokens=*" %%i in ('rasdial') do (
    if not "%%i"=="No connections" (
        for /f "tokens=1" %%j in ("%%i") do rasdial "%%j" /disconnect >nul 2>&1
    )
)

:: Clear VPN profiles
reg delete "HKEY_CURRENT_USER\Software\Microsoft\RAS Phonebook" /f >nul 2>&1

:: Reset BITS (Background Intelligent Transfer Service)
call :log_message "INFO" "Resetting BITS..."
bitsadmin /reset /allusers >nul 2>&1

:: Restart network-related services
call :log_message "INFO" "Restarting network services..."
call :restart_service "DHCP"
call :restart_service "Dnscache"
call :restart_service "lmhosts"
call :restart_service "netlogon"
call :restart_service "nsi"
call :restart_service "netman"
call :restart_service "NlaSvc"

:: Reset network adapter hardware
call :log_message "INFO" "Resetting network adapter hardware..."
powershell -command "Get-NetAdapter | Restart-NetAdapter -Confirm:$false" >nul 2>&1

:: Release and renew IP addresses
call :log_message "INFO" "Releasing and renewing IP addresses..."
ipconfig /release >nul 2>&1
timeout /t 2 /nobreak >nul
ipconfig /renew >nul 2>&1

:: Register network services
call :log_message "INFO" "Re-registering network services..."
regsvr32 /s netshell.dll
regsvr32 /s netcfgx.dll
regsvr32 /s netman.dll

call :log_message "SUCCESS" "Network Adapter Reset completed"
echo.
echo Network adapter settings have been reset to defaults.
echo Changes include:
echo - TCP/IP stack reset
echo - Winsock catalog reset
echo - DNS cache flushed
echo - Network adapters set to DHCP
echo - Windows Firewall reset
echo - Proxy settings cleared
echo - Network location set to Public
echo - Network services restarted
echo.
echo A system restart is REQUIRED for all changes to take effect.
echo.
echo Backup created at: %LAST_BACKUP%
echo Log file: %LOG_FILE%
echo.

if /i not "%SILENT_MODE%"=="true" (
    echo The system must be restarted to complete the network reset.
    echo Would you like to restart now? (y/N)
    set /p "RESTART=Enter your choice: "
    if /i "%RESTART%"=="y" (
        call :log_message "INFO" "System restart initiated by user"
        shutdown /r /t 30 /c "Restarting to complete network adapter reset..."
        echo System will restart in 30 seconds...
    ) else (
        echo Please restart your computer manually to complete the network reset.
    )
)

call :log_message "INFO" "Network Adapter Reset completed"
exit /b 0