# Windows Settings Reset Toolkit - PowerShell Installation Script
# Sets up the ReSet toolkit for first-time use with enhanced PowerShell functionality

[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$Force,
    [string]$InstallPath = $PSScriptRoot,
    [switch]$CreateRestorePoint = $true,
    [switch]$SkipShortcuts,
    [switch]$Uninstall
)

#Requires -Version 5.0
#Requires -RunAsAdministrator

# Enhanced error handling and strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Global variables
$Script:InstallDir = $InstallPath
$Script:LogFile = $null
$Script:ValidationErrors = 0

# Console colors for professional output
$Colors = @{
    Header = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; 
    Info = 'White'; Muted = 'DarkGray'; Emphasis = 'Magenta'
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n$('=' * 60)" -ForegroundColor $Colors.Header
    Write-Host " $Message" -ForegroundColor $Colors.Header
    Write-Host "$('=' * 60)" -ForegroundColor $Colors.Header
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $Colors.Success
    Write-LogEntry "SUCCESS" $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning
    Write-LogEntry "WARNING" $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Colors.Error
    Write-LogEntry "ERROR" $Message
    $Script:ValidationErrors++
}

function Write-Info {
    param([string]$Message)
    Write-Host "• $Message" -ForegroundColor $Colors.Info
    Write-LogEntry "INFO" $Message
}

function Write-LogEntry {
    param([string]$Level, [string]$Message)
    if ($Script:LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] [$Level] $Message" | Out-File -FilePath $Script:LogFile -Append -Encoding UTF8
    }
}

function Test-Prerequisites {
    Write-Header "SYSTEM PREREQUISITES CHECK"
    
    # Check Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    $osName = (Get-WmiObject Win32_OperatingSystem).Caption
    Write-Info "Checking Windows version: $osName"
    
    if ($osVersion.Major -ge 10) {
        Write-Success "Windows 10/11 detected - Full compatibility"
    } elseif ($osVersion.Major -eq 6 -and $osVersion.Minor -ge 1) {
        Write-Warning "Windows 7/8 detected - Limited compatibility"
        if (-not $Force) {
            $continue = Read-Host "Continue installation? (y/N)"
            if ($continue -notmatch '^(y|yes)$') {
                throw "Installation cancelled by user"
            }
        }
    } else {
        throw "Unsupported Windows version. Windows 10/11 required."
    }
    
    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Info "Checking PowerShell version: $psVersion"
    
    if ($psVersion.Major -ge 5) {
        Write-Success "PowerShell $psVersion - Full compatibility"
    } else {
        throw "PowerShell 5.0 or higher is required. Current version: $psVersion"
    }
    
    # Check .NET Framework
    try {
        $netVersion = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
        if ($netVersion -and $netVersion.Release -ge 461808) {
            Write-Success ".NET Framework 4.7.2+ detected"
        } else {
            Write-Warning ".NET Framework 4.7.2+ recommended for full functionality"
        }
    } catch {
        Write-Warning "Could not determine .NET Framework version"
    }
    
    # Check available disk space (minimum 1GB)
    $drive = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq (Split-Path $Script:InstallDir -Qualifier) }
    $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
    Write-Info "Available disk space: $freeSpaceGB GB"
    
    if ($freeSpaceGB -lt 1) {
        Write-Warning "Low disk space detected. At least 1GB recommended for backups."
    } else {
        Write-Success "Sufficient disk space available"
    }
}

function New-DirectoryStructure {
    Write-Header "CREATING DIRECTORY STRUCTURE"
    
    $directories = @{
        'scripts' = 'PowerShell reset scripts'
        'logs' = 'Operation and installation logs'
        'backups' = 'Registry and file backups'
        'gui' = 'GUI application files'
        'cli' = 'Command-line interface files'
        'docs' = 'Documentation and help files'
        'modules' = 'PowerShell modules and utilities'
        'config' = 'Configuration files'
        'templates' = 'Script templates and examples'
    }
    
    foreach ($dir in $directories.Keys) {
        $fullPath = Join-Path $Script:InstallDir $dir
        $description = $directories[$dir]
        
        if (-not (Test-Path $fullPath)) {
            try {
                New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
                Write-Success "Created '$dir' directory - $description"
            } catch {
                Write-Error "Failed to create '$dir' directory: $($_.Exception.Message)"
            }
        } else {
            Write-Info "'$dir' directory already exists"
        }
    }
}

function Initialize-Logging {
    $logsDir = Join-Path $Script:InstallDir "logs"
    $logFileName = "installation-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').log"
    $Script:LogFile = Join-Path $logsDir $logFileName
    
    try {
        if (-not (Test-Path $logsDir)) {
            New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
        }
        
        $logHeader = @"
===============================================
ReSet Toolkit PowerShell Installation Log
===============================================
Installation Date: $(Get-Date)
Computer: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $([System.Environment]::OSVersion.VersionString)
Install Path: $Script:InstallDir
===============================================

"@
        $logHeader | Out-File -FilePath $Script:LogFile -Encoding UTF8
        Write-Success "Logging initialized: $logFileName"
    } catch {
        Write-Warning "Could not initialize logging: $($_.Exception.Message)"
    }
}

function New-SystemRestorePoint {
    if (-not $CreateRestorePoint) { return }
    
    Write-Header "CREATING SYSTEM RESTORE POINT"
    
    try {
        $restorePointName = "ReSet Toolkit - PowerShell Installation $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Write-Info "Creating restore point: $restorePointName"
        
        Checkpoint-Computer -Description $restorePointName -RestorePointType "APPLICATION_INSTALL"
        Write-Success "System restore point created successfully"
    } catch {
        Write-Warning "Could not create system restore point: $($_.Exception.Message)"
        Write-Info "Installation will continue without restore point"
    }
}

function Install-PowerShellModules {
    Write-Header "INSTALLING POWERSHELL MODULES"
    
    $modulesDir = Join-Path $Script:InstallDir "modules"
    
    # Create utils module
    $utilsModule = Join-Path $modulesDir "ReSetUtils.psm1"
    try {
        $utilsContent = @'
# ReSet Toolkit PowerShell Utilities Module
# Provides common functions for all reset scripts

#Requires -Version 5.0

function Write-ReSetLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$LogPath = $null
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    $color = switch ($Level) {
        'SUCCESS' { 'Green' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'Cyan' }
        default { 'White' }
    }
    
    Write-Host $logEntry -ForegroundColor $color
    
    # File output
    if ($LogPath) {
        $logEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8
    }
}

function Backup-RegistryKey {
    param(
        [Parameter(Mandatory)]
        [string]$KeyPath,
        
        [Parameter(Mandatory)]
        [string]$BackupName,
        
        [string]$BackupDir = (Join-Path $PSScriptRoot "..\backups")
    )
    
    try {
        if (-not (Test-Path $BackupDir)) {
            New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = Join-Path $BackupDir "$BackupName-$timestamp.reg"
        
        $process = Start-Process -FilePath "reg.exe" -ArgumentList "export", "`"$KeyPath`"", "`"$backupFile`"", "/y" -Wait -PassThru -WindowStyle Hidden
        
        if ($process.ExitCode -eq 0 -and (Test-Path $backupFile)) {
            Write-ReSetLog -Level 'SUCCESS' -Message "Registry backup created: $backupFile"
            return $backupFile
        } else {
            throw "Registry export failed with exit code: $($process.ExitCode)"
        }
    } catch {
        Write-ReSetLog -Level 'ERROR' -Message "Failed to backup registry key '$KeyPath': $($_.Exception.Message)"
        return $null
    }
}

function Confirm-ReSetAction {
    param(
        [Parameter(Mandatory)]
        [string]$Action,
        
        [string]$RiskLevel = "Medium",
        
        [switch]$Force
    )
    
    if ($Force) { return $true }
    
    $riskColor = switch ($RiskLevel) {
        'Low' { 'Green' }
        'High' { 'Red' }
        default { 'Yellow' }
    }
    
    Write-Host "`n[CONFIRMATION REQUIRED]" -ForegroundColor $riskColor
    Write-Host "Action: $Action" -ForegroundColor White
    Write-Host "Risk Level: $RiskLevel" -ForegroundColor $riskColor
    Write-Host ""
    
    $response = Read-Host "Do you want to proceed? (y/N)"
    return ($response -match '^(y|yes)$')
}

function Test-AdminPrivileges {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ReSetConfig {
    param([string]$ConfigPath = (Join-Path $PSScriptRoot "..\config.ini"))
    
    $config = @{}
    
    if (Test-Path $ConfigPath) {
        $currentSection = ""
        Get-Content $ConfigPath | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^\[(.+)\]$') {
                $currentSection = $matches[1]
                $config[$currentSection] = @{}
            } elseif ($line -match '^(.+?)=(.*)$' -and $currentSection) {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $config[$currentSection][$key] = $value
            }
        }
    }
    
    return $config
}

Export-ModuleMember -Function @(
    'Write-ReSetLog',
    'Backup-RegistryKey', 
    'Confirm-ReSetAction',
    'Test-AdminPrivileges',
    'Get-ReSetConfig'
)
'@
        
        $utilsContent | Out-File -FilePath $utilsModule -Encoding UTF8
        Write-Success "Created PowerShell utilities module"
    } catch {
        Write-Error "Failed to create utilities module: $($_.Exception.Message)"
    }
}

function New-ConfigurationFile {
    Write-Header "CREATING CONFIGURATION"
    
    $configFile = Join-Path $Script:InstallDir "config.ini"
    
    if (Test-Path $configFile) {
        Write-Info "Configuration file already exists"
        return
    }
    
    try {
        $configContent = @"
# ReSet Toolkit Configuration File
# PowerShell Version - Enhanced Settings

[Settings]
Version=2.1
Language=en-US
LogLevel=INFO
AutoBackup=true
ConfirmActions=true
CreateRestorePoints=true
SilentMode=false

[Paths]
ScriptsPath=scripts
LogsPath=logs
BackupsPath=backups
ModulesPath=modules
ConfigPath=config

[Categories]
DisplayOrder=Language & Regional,Display & Audio,Network & Connectivity,Security & Privacy,Search & Interface,File Management,Performance & Power,Applications & Store,Input & Accessibility,System Components

[UI]
Theme=Light
WindowWidth=1200
WindowHeight=800
ShowTooltips=true
AutoRefresh=true

[Advanced]
EnableDebugMode=false
MaxLogEntries=1000
BackupRetentionDays=30
EnableTelemetry=false
ParallelExecution=false
MaxRetries=3
TimeoutSeconds=300

[PowerShell]
ExecutionPolicy=RemoteSigned
RequiredVersion=5.0
PreferredVersion=7.0
ModuleAutoLoad=true
VerboseLogging=false

[Security]
RequireElevation=true
ValidateScripts=true
EnableScriptSigning=false
TrustedPublishers=Microsoft Corporation

[Backup]
CompressionEnabled=true
EncryptionEnabled=false
MaxBackupSize=500MB
AutoCleanup=true
VerifyBackups=true
"@
        
        $configContent | Out-File -FilePath $configFile -Encoding UTF8
        Write-Success "Configuration file created with PowerShell enhancements"
    } catch {
        Write-Error "Failed to create configuration file: $($_.Exception.Message)"
    }
}

function New-Shortcuts {
    if ($SkipShortcuts) { return }
    
    Write-Header "CREATING SHORTCUTS AND MENU ENTRIES"
    
    # Desktop shortcuts
    $desktop = [Environment]::GetFolderPath("Desktop")
    if (Test-Path $desktop) {
        try {
            $wshell = New-Object -ComObject WScript.Shell
            
            # Main toolkit shortcut
            $mainShortcut = $wshell.CreateShortcut((Join-Path $desktop "ReSet Toolkit.lnk"))
            $mainShortcut.TargetPath = "powershell.exe"
            $mainShortcut.Arguments = "-ExecutionPolicy Bypass -File `"$(Join-Path $Script:InstallDir 'Install-ReSet.ps1')`" -LaunchMain"
            $mainShortcut.WorkingDirectory = $Script:InstallDir
            $mainShortcut.Description = "Windows Settings Reset Toolkit - PowerShell Edition"
            $mainShortcut.Save()
            
            # GUI shortcut
            $guiPath = Join-Path $Script:InstallDir "gui\ReSetGUI.ps1"
            if (Test-Path $guiPath) {
                $guiShortcut = $wshell.CreateShortcut((Join-Path $desktop "ReSet Toolkit GUI.lnk"))
                $guiShortcut.TargetPath = "powershell.exe"
                $guiShortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guiPath`""
                $guiShortcut.WorkingDirectory = $Script:InstallDir
                $guiShortcut.Description = "ReSet Toolkit - Graphical Interface"
                $guiShortcut.Save()
            }
            
            # CLI shortcut
            $cliPath = Join-Path $Script:InstallDir "cli\ReSetCLI.ps1"
            if (Test-Path $cliPath) {
                $cliShortcut = $wshell.CreateShortcut((Join-Path $desktop "ReSet Toolkit CLI.lnk"))
                $cliShortcut.TargetPath = "powershell.exe"
                $cliShortcut.Arguments = "-ExecutionPolicy Bypass -NoExit -File `"$cliPath`""
                $cliShortcut.WorkingDirectory = $Script:InstallDir
                $cliShortcut.Description = "ReSet Toolkit - Command Line Interface"
                $cliShortcut.Save()
            }
            
            Write-Success "Desktop shortcuts created"
        } catch {
            Write-Warning "Could not create desktop shortcuts: $($_.Exception.Message)"
        }
    }
    
    # Start Menu entries
    $startMenu = Join-Path ([Environment]::GetFolderPath("Programs")) "ReSet Toolkit"
    try {
        if (-not (Test-Path $startMenu)) {
            New-Item -Path $startMenu -ItemType Directory -Force | Out-Null
        }
        
        $wshell = New-Object -ComObject WScript.Shell
        
        # Main entry
        $mainEntry = $wshell.CreateShortcut((Join-Path $startMenu "ReSet Toolkit.lnk"))
        $mainEntry.TargetPath = "powershell.exe"
        $mainEntry.Arguments = "-ExecutionPolicy Bypass -File `"$(Join-Path $Script:InstallDir 'Install-ReSet.ps1')`" -LaunchMain"
        $mainEntry.WorkingDirectory = $Script:InstallDir
        $mainEntry.Save()
        
        # Individual script shortcuts
        $scriptShortcuts = @{
            'Network Reset' = 'reset-network.ps1'
            'Display Reset' = 'reset-display.ps1'
            'Audio Reset' = 'reset-audio.ps1'
            'Browser Reset' = 'reset-browser.ps1'
        }
        
        foreach ($name in $scriptShortcuts.Keys) {
            $scriptFile = Join-Path $Script:InstallDir "scripts\$($scriptShortcuts[$name])"
            if (Test-Path $scriptFile) {
                $shortcut = $wshell.CreateShortcut((Join-Path $startMenu "$name.lnk"))
                $shortcut.TargetPath = "powershell.exe"
                $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$scriptFile`""
                $shortcut.WorkingDirectory = $Script:InstallDir
                $shortcut.Save()
            }
        }
        
        Write-Success "Start Menu entries created"
    } catch {
        Write-Warning "Could not create Start Menu entries: $($_.Exception.Message)"
    }
}

function Set-EnvironmentVariables {
    Write-Header "CONFIGURING ENVIRONMENT"
    
    try {
        # Set RESET_TOOLKIT_HOME
        [Environment]::SetEnvironmentVariable("RESET_TOOLKIT_HOME", $Script:InstallDir, "User")
        Write-Success "RESET_TOOLKIT_HOME environment variable set"
        
        # Add to PATH if not already present
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$Script:InstallDir*") {
            $newPath = if ($userPath) { "$userPath;$Script:InstallDir" } else { $Script:InstallDir }
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-Success "Added toolkit directory to user PATH"
        } else {
            Write-Info "Toolkit directory already in PATH"
        }
        
        # Set PowerShell execution policy if needed
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        if ($currentPolicy -eq 'Restricted') {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Success "PowerShell execution policy updated to RemoteSigned"
        } else {
            Write-Info "PowerShell execution policy: $currentPolicy"
        }
    } catch {
        Write-Warning "Could not configure environment variables: $($_.Exception.Message)"
    }
}

function New-UninstallScript {
    Write-Header "CREATING UNINSTALL SCRIPT"
    
    $uninstallScript = Join-Path $Script:InstallDir "Uninstall-ReSet.ps1"
    
    try {
        $uninstallContent = @"
# ReSet Toolkit - PowerShell Uninstall Script
[CmdletBinding()]
param([switch]`$Silent)

#Requires -RunAsAdministrator

Write-Host "ReSet Toolkit PowerShell Uninstaller" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan

if (-not `$Silent) {
    `$confirm = Read-Host "Are you sure you want to uninstall ReSet Toolkit? (y/N)"
    if (`$confirm -notmatch '^(y|yes)$') {
        Write-Host "Uninstall cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Remove environment variables
try {
    [Environment]::SetEnvironmentVariable("RESET_TOOLKIT_HOME", `$null, "User")
    Write-Host "✓ Removed RESET_TOOLKIT_HOME environment variable" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not remove environment variable" -ForegroundColor Yellow
}

# Remove from PATH
try {
    `$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if (`$userPath -like "*$Script:InstallDir*") {
        `$newPath = `$userPath -replace [regex]::Escape(";$Script:InstallDir"), ""
        `$newPath = `$newPath -replace [regex]::Escape("$Script:InstallDir;"), ""
        `$newPath = `$newPath -replace [regex]::Escape("$Script:InstallDir"), ""
        [Environment]::SetEnvironmentVariable("PATH", `$newPath, "User")
        Write-Host "✓ Removed from user PATH" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Could not update PATH" -ForegroundColor Yellow
}

# Remove shortcuts
try {
    `$desktop = [Environment]::GetFolderPath("Desktop")
    @("ReSet Toolkit.lnk", "ReSet Toolkit GUI.lnk", "ReSet Toolkit CLI.lnk") | ForEach-Object {
        `$shortcut = Join-Path `$desktop `$_
        if (Test-Path `$shortcut) {
            Remove-Item `$shortcut -Force
        }
    }
    Write-Host "✓ Removed desktop shortcuts" -ForegroundColor Green
} catch {
    Write-Host "⚠ Could not remove all shortcuts" -ForegroundColor Yellow
}

# Remove Start Menu entries
try {
    `$startMenu = Join-Path ([Environment]::GetFolderPath("Programs")) "ReSet Toolkit"
    if (Test-Path `$startMenu) {
        Remove-Item `$startMenu -Recurse -Force
        Write-Host "✓ Removed Start Menu entries" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠ Could not remove Start Menu entries" -ForegroundColor Yellow
}

Write-Host "`nReSet Toolkit has been uninstalled." -ForegroundColor Green
Write-Host "Installation files remain in: $Script:InstallDir" -ForegroundColor Yellow
Write-Host "Delete this folder manually if desired." -ForegroundColor Yellow

if (-not `$Silent) {
    Read-Host "`nPress Enter to continue"
}
"@
        
        $uninstallContent | Out-File -FilePath $uninstallScript -Encoding UTF8
        Write-Success "Uninstall script created"
    } catch {
        Write-Error "Failed to create uninstall script: $($_.Exception.Message)"
    }
}

function Test-Installation {
    Write-Header "VALIDATING INSTALLATION"
    
    $validationTests = @{
        'Main installation directory' = { Test-Path $Script:InstallDir }
        'Scripts directory' = { Test-Path (Join-Path $Script:InstallDir "scripts") }
        'Logs directory' = { Test-Path (Join-Path $Script:InstallDir "logs") }
        'Backups directory' = { Test-Path (Join-Path $Script:InstallDir "backups") }
        'Configuration file' = { Test-Path (Join-Path $Script:InstallDir "config.ini") }
        'PowerShell utilities module' = { Test-Path (Join-Path $Script:InstallDir "modules\ReSetUtils.psm1") }
        'Uninstall script' = { Test-Path (Join-Path $Script:InstallDir "Uninstall-ReSet.ps1") }
    }
    
    $passed = 0
    $total = $validationTests.Count
    
    foreach ($test in $validationTests.Keys) {
        $result = & $validationTests[$test]
        if ($result) {
            Write-Success $test
            $passed++
        } else {
            Write-Error "Missing: $test"
        }
    }
    
    # Count PowerShell scripts
    $scriptsDir = Join-Path $Script:InstallDir "scripts"
    if (Test-Path $scriptsDir) {
        $scriptCount = (Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -ErrorAction SilentlyContinue).Count
        Write-Info "Found $scriptCount PowerShell scripts"
        
        if ($scriptCount -ge 20) {
            Write-Success "Adequate number of reset scripts available"
            $passed++
            $total++
        } else {
            Write-Warning "Expected 20+ reset scripts, found $scriptCount"
        }
    }
    
    Write-Host "`nValidation Results: $passed/$total tests passed" -ForegroundColor ($passed -eq $total ? $Colors.Success : $Colors.Warning)
    
    if ($passed -ne $total) {
        Write-Warning "Installation completed with issues. Some features may not work correctly."
    }
}

function Show-CompletionSummary {
    Write-Header "INSTALLATION COMPLETE"
    
    Write-Host "The ReSet Toolkit PowerShell Edition has been successfully installed!" -ForegroundColor $Colors.Success
    Write-Host ""
    Write-Host "Installation Details:" -ForegroundColor $Colors.Emphasis
    Write-Host "  Location: $Script:InstallDir" -ForegroundColor $Colors.Info
    Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor $Colors.Info
    Write-Host "  Configuration: config.ini" -ForegroundColor $Colors.Info
    Write-Host "  Log File: $(Split-Path $Script:LogFile -Leaf)" -ForegroundColor $Colors.Info
    Write-Host ""
    
    Write-Host "Usage Options:" -ForegroundColor $Colors.Emphasis
    Write-Host "  • GUI Interface: ReSet Toolkit GUI (desktop shortcut)" -ForegroundColor $Colors.Info
    Write-Host "  • Command Line: ReSet Toolkit CLI (desktop shortcut)" -ForegroundColor $Colors.Info
    Write-Host "  • PowerShell: Import-Module '$(Join-Path $Script:InstallDir 'modules\ReSetUtils.psm1')'" -ForegroundColor $Colors.Info
    Write-Host "  • Individual Scripts: Run scripts from the scripts folder" -ForegroundColor $Colors.Info
    Write-Host ""
    
    Write-Host "Quick Start Examples:" -ForegroundColor $Colors.Emphasis
    Write-Host "  .\scripts\Reset-Network.ps1" -ForegroundColor $Colors.Muted
    Write-Host "  .\scripts\Reset-Display.ps1 -Force" -ForegroundColor $Colors.Muted
    Write-Host "  .\cli\ReSetCLI.ps1 -QuickScan" -ForegroundColor $Colors.Muted
    Write-Host ""
    
    Write-Host "Support:" -ForegroundColor $Colors.Emphasis
    Write-Host "  • Documentation: README.md" -ForegroundColor $Colors.Info
    Write-Host "  • Logs: logs/ directory" -ForegroundColor $Colors.Info
    Write-Host "  • Backups: backups/ directory" -ForegroundColor $Colors.Info
    Write-Host "  • Uninstall: .\Uninstall-ReSet.ps1" -ForegroundColor $Colors.Info
    Write-Host ""
    
    if ($Script:ValidationErrors -eq 0) {
        Write-Host "Installation Status: SUCCESS" -ForegroundColor $Colors.Success
    } else {
        Write-Host "Installation Status: COMPLETED WITH $($Script:ValidationErrors) WARNINGS" -ForegroundColor $Colors.Warning
    }
}

function Invoke-Uninstall {
    Write-Header "UNINSTALLING RESET TOOLKIT"
    
    $uninstallScript = Join-Path $Script:InstallDir "Uninstall-ReSet.ps1"
    if (Test-Path $uninstallScript) {
        & $uninstallScript -Silent:$Silent
    } else {
        Write-Error "Uninstall script not found: $uninstallScript"
    }
}

# Main execution
try {
    if ($Uninstall) {
        Invoke-Uninstall
        return
    }
    
    Write-Header "RESET TOOLKIT POWERSHELL INSTALLATION"
    Write-Host "Enhanced PowerShell Edition - Professional Administrator Tools" -ForegroundColor $Colors.Emphasis
    Write-Host ""
    
    if (-not $Silent) {
        Write-Host "This installer will set up the ReSet Toolkit with full PowerShell integration." -ForegroundColor $Colors.Info
        Write-Host "Administrator privileges are required for complete installation." -ForegroundColor $Colors.Warning
        Write-Host ""
        
        $continue = Read-Host "Continue with installation? (Y/n)"
        if ($continue -match '^n') {
            Write-Host "Installation cancelled." -ForegroundColor $Colors.Warning
            exit 0
        }
    }
    
    Initialize-Logging
    Test-Prerequisites
    New-DirectoryStructure
    New-SystemRestorePoint
    Install-PowerShellModules
    New-ConfigurationFile
    New-Shortcuts
    Set-EnvironmentVariables
    New-UninstallScript
    Test-Installation
    Show-CompletionSummary
    
    if (-not $Silent) {
        Write-Host ""
        $launch = Read-Host "Would you like to launch the ReSet Toolkit now? (y/N)"
        if ($launch -match '^(y|yes)$') {
            $guiPath = Join-Path $Script:InstallDir "gui\ReSetGUI.ps1"
            $cliPath = Join-Path $Script:InstallDir "cli\ReSetCLI.ps1"
            
            if (Test-Path $guiPath) {
                Write-Host "Launching GUI interface..." -ForegroundColor $Colors.Info
                Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guiPath`""
            } elseif (Test-Path $cliPath) {
                Write-Host "Launching CLI interface..." -ForegroundColor $Colors.Info
                & $cliPath
            } else {
                Write-Warning "No interface scripts found. Installation may be incomplete."
            }
        }
    }
    
} catch {
    Write-Host "`nInstallation failed: $($_.Exception.Message)" -ForegroundColor $Colors.Error
    Write-LogEntry "ERROR" "Installation failed: $($_.Exception.Message)"
    
    if ($_.Exception.InnerException) {
        Write-Host "Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor $Colors.Error
    }
    
    Write-Host "`nFor support, check the installation log: $Script:LogFile" -ForegroundColor $Colors.Info
    exit 1
}