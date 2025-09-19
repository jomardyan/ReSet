# Windows Settings Reset Toolkit - Network Adapter Reset# Windows Settings Reset Toolkit - Network Adapter Reset

# Resets TCP/IP stack, DNS settings, Windows Firewall, and network adapter configurations

param(

param(    [switch]$Silent,

    [switch]$Silent,    [switch]$VerifyBackup,

    [switch]$VerifyBackup,    [string]$BackupPath

    [string]$BackupPath)

)

# Set window title

# Set window title$scriptTitle = ($batFile.BaseName -replace 'reset-', '') -replace '-', ' '

$Host.UI.RawUI.WindowTitle = "ReSet - Network Adapter Reset"$scriptTitle = (Get-Culture).TextInfo.ToTitleCase($scriptTitle)

$Host.UI.RawUI.WindowTitle = "ReSet - $scriptTitle Reset"

# Import utils module

$utilsPath = Join-Path $PSScriptRoot "utils.ps1"# Import utils module

if (Test-Path $utilsPath) {$utilsPath = Join-Path $PSScriptRoot "utils.ps1"

    Import-Module $utilsPath -Force -Globalif (Test-Path $utilsPath) {

} else {    Import-Module $utilsPath -Force -Global

    Write-Error "Utils module not found: $utilsPath"} else {

    exit 1    Write-Error "Utils module not found: $utilsPath"

}    exit 1

}

# Initialize global variables from parameters

$global:SILENT_MODE = $Silent.IsPresent# Initialize global variables from parameters

$global:VERIFY_BACKUP = $VerifyBackup.IsPresent$global:SILENT_MODE = $Silent.IsPresent

if ($BackupPath) { $global:BACKUP_DIR = $BackupPath }$global:VERIFY_BACKUP = $VerifyBackup.IsPresent

if ($BackupPath) { $global:BACKUP_DIR = $BackupPath }

Write-LogMessage -Level "INFO" -Message "Starting Network Adapter Reset"

Test-WindowsVersion | Out-NullWrite-LogMessage -Level "INFO" -Message "Starting Windows Settings Reset Toolkit - Network Adapter Reset"

Test-WindowsVersion | Out-Null

# Confirm action

if (-not (Confirm-Action -Action "reset all network adapter settings and configurations")) {# Confirm action (this would need to be customized per script)

    exit 1if (-not (Confirm-Action -Action "reset settings (please customize this message for the specific script)")) {

}    exit 1

}

# Create backups

Write-LogMessage -Level "INFO" -Message "Creating registry backups..."# TODO: Convert the specific functionality from the BAT file

Backup-Registry -RegistryKey "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -BackupName "tcpip_parameters"# This is a template - each script needs its specific implementation

Backup-Registry -RegistryKey "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -BackupName "internet_settings"

Write-LogMessage -Level "INFO" -Message "This script needs manual conversion from BAT to PowerShell"

Write-LogMessage -Level "WARN" -Message "Network connectivity will be temporarily lost during reset"Write-Host "This PowerShell script is a template and needs to be manually implemented." -ForegroundColor Yellow

if (-not $global:SILENT_MODE) {Write-Host "Original BAT file: $(/workspaces/ReSet/scripts/reset-network.bat.FullName)" -ForegroundColor Gray

    Write-Host "Network connectivity will be temporarily lost. Continue? (y/N)" -ForegroundColor YellowWrite-Host "Please review the BAT file content and implement the PowerShell equivalent." -ForegroundColor Gray

    $continue = Read-Host

    if ($continue -ne "y" -and $continue -ne "Y") {Write-LogMessage -Level "SUCCESS" -Message "Windows Settings Reset Toolkit - Network Adapter Reset template created"

        Write-Host "Operation cancelled." -ForegroundColor YellowWrite-Host ""

        exit 1Write-Host "Template created. Manual implementation required." -ForegroundColor Yellow

    }Write-Host "Log file: $global:LOG_FILE" -ForegroundColor Cyan

}

Write-LogMessage -Level "INFO" -Message "Windows Settings Reset Toolkit - Network Adapter Reset template completed"

# Reset Winsock catalogexit 0

Write-LogMessage -Level "INFO" -Message "Resetting Winsock catalog..."
try {
    $result = Start-Process -FilePath "netsh" -ArgumentList "winsock", "reset" -WindowStyle Hidden -PassThru -Wait
    if ($result.ExitCode -eq 0) {
        Write-LogMessage -Level "SUCCESS" -Message "Winsock catalog reset"
    } else {
        Write-LogMessage -Level "ERROR" -Message "Failed to reset Winsock catalog"
    }
} catch {
    Write-LogMessage -Level "ERROR" -Message "Error resetting Winsock catalog: $($_.Exception.Message)"
}

# Reset TCP/IP stack
Write-LogMessage -Level "INFO" -Message "Resetting TCP/IP stack..."
try {
    $result = Start-Process -FilePath "netsh" -ArgumentList "int", "ip", "reset" -WindowStyle Hidden -PassThru -Wait
    if ($result.ExitCode -eq 0) {
        Write-LogMessage -Level "SUCCESS" -Message "TCP/IP stack reset"
    } else {
        Write-LogMessage -Level "ERROR" -Message "Failed to reset TCP/IP stack"
    }
} catch {
    Write-LogMessage -Level "ERROR" -Message "Error resetting TCP/IP stack: $($_.Exception.Message)"
}

# Reset IPv6 configuration  
Write-LogMessage -Level "INFO" -Message "Resetting IPv6 configuration..."
try {
    $result = Start-Process -FilePath "netsh" -ArgumentList "interface", "ipv6", "reset" -WindowStyle Hidden -PassThru -Wait
    if ($result.ExitCode -eq 0) {
        Write-LogMessage -Level "SUCCESS" -Message "IPv6 configuration reset"
    } else {
        Write-LogMessage -Level "ERROR" -Message "Failed to reset IPv6 configuration"
    }
} catch {
    Write-LogMessage -Level "ERROR" -Message "Error resetting IPv6 configuration: $($_.Exception.Message)"
}

# Reset network adapters to DHCP
Write-LogMessage -Level "INFO" -Message "Resetting network adapters to DHCP..."
try {
    $networkAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $networkAdapters) {
        Write-LogMessage -Level "INFO" -Message "Resetting adapter: $($adapter.Name)"
        
        # Reset to DHCP for IPv4
        Remove-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceAlias $adapter.Name -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Set-NetIPInterface -InterfaceAlias $adapter.Name -AddressFamily IPv4 -Dhcp Enabled -ErrorAction SilentlyContinue
        
        # Reset DNS to automatic
        Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses -ErrorAction SilentlyContinue
    }
    Write-LogMessage -Level "SUCCESS" -Message "Network adapters reset to DHCP"
} catch {
    Write-LogMessage -Level "ERROR" -Message "Error resetting network adapters: $($_.Exception.Message)"
}

# Flush DNS cache
Write-LogMessage -Level "INFO" -Message "Flushing DNS cache..."
try {
    $result = Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -WindowStyle Hidden -PassThru -Wait
    if ($result.ExitCode -eq 0) {
        Write-LogMessage -Level "SUCCESS" -Message "DNS cache flushed"
    } else {
        Write-LogMessage -Level "ERROR" -Message "Failed to flush DNS cache"
    }
} catch {
    Write-LogMessage -Level "ERROR" -Message "Error flushing DNS cache: $($_.Exception.Message)"
}

# Reset Windows Firewall to defaults
Write-LogMessage -Level "INFO" -Message "Resetting Windows Firewall to defaults..."
try {
    $result = Start-Process -FilePath "netsh" -ArgumentList "advfirewall", "reset" -WindowStyle Hidden -PassThru -Wait
    if ($result.ExitCode -eq 0) {
        Write-LogMessage -Level "SUCCESS" -Message "Windows Firewall reset to defaults"
    } else {
        Write-LogMessage -Level "ERROR" -Message "Failed to reset Windows Firewall"
    }
} catch {
    Write-LogMessage -Level "ERROR" -Message "Error resetting Windows Firewall: $($_.Exception.Message)"
}

# Reset proxy settings
Write-LogMessage -Level "INFO" -Message "Resetting proxy settings..."
try {
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0 -Type "DWord"
    Remove-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer"
    Remove-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyOverride"
    Write-LogMessage -Level "SUCCESS" -Message "Proxy settings reset"
} catch {
    Write-LogMessage -Level "ERROR" -Message "Error resetting proxy settings: $($_.Exception.Message)"
}

# Restart network-related services
Write-LogMessage -Level "INFO" -Message "Restarting network services..."
$servicesToRestart = @("Dnscache", "Dhcp", "LanmanWorkstation", "LanmanServer")
foreach ($serviceName in $servicesToRestart) {
    try {
        Restart-WindowsService -ServiceName $serviceName
    } catch {
        Write-LogMessage -Level "WARN" -Message "Could not restart service $serviceName`: $($_.Exception.Message)"
    }
}

# Release and renew IP addresses
Write-LogMessage -Level "INFO" -Message "Renewing IP addresses..."
try {
    Start-Process -FilePath "ipconfig" -ArgumentList "/release" -WindowStyle Hidden -PassThru -Wait | Out-Null
    Start-Sleep -Seconds 2
    Start-Process -FilePath "ipconfig" -ArgumentList "/renew" -WindowStyle Hidden -PassThru -Wait | Out-Null
    Write-LogMessage -Level "SUCCESS" -Message "IP addresses renewed"
} catch {
    Write-LogMessage -Level "WARN" -Message "Error renewing IP addresses: $($_.Exception.Message)"
}

Write-LogMessage -Level "SUCCESS" -Message "Network Adapter Reset completed"
Write-Host ""
Write-Host "Network adapter settings have been reset to defaults." -ForegroundColor Green
Write-Host "Backup created at: $global:LAST_BACKUP" -ForegroundColor Cyan  
Write-Host "Log file: $global:LOG_FILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Red
Write-Host "• A system restart is REQUIRED for all changes to take effect" -ForegroundColor Yellow
Write-Host "• Network connectivity may be temporarily affected" -ForegroundColor Yellow
Write-Host "• Reconfigure static IP addresses if needed after restart" -ForegroundColor Yellow

if (-not $global:SILENT_MODE) {
    $restart = Read-Host "Would you like to restart now? (y/N)"
    if ($restart -eq "y" -or $restart -eq "Y") {
        Write-LogMessage -Level "INFO" -Message "System restart initiated by user"
        Start-Process -FilePath "shutdown" -ArgumentList "/r", "/t", "10", "/c", "Restarting to complete network reset..." -WindowStyle Hidden
    }
}

Write-LogMessage -Level "INFO" -Message "Network Adapter Reset completed"
exit 0