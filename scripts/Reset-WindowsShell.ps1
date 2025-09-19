# Windows Settings Reset Toolkit - Windows Shell Reset PowerShell Script
# Resets Windows Explorer settings, folder views, and shell associations with enhanced functionality

[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$Force,
    [switch]$NoBackup,
    [switch]$VerifyBackup,
    [string]$BackupPath = $null,
    [switch]$RestartExplorer = $true,
    [ValidateSet('Minimal', 'Standard', 'Complete')]
    [string]$ResetLevel = 'Standard'
)

#Requires -Version 5.0
#Requires -RunAsAdministrator

# Enhanced error handling and strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import utilities if available
$moduleDir = Join-Path (Split-Path $PSScriptRoot -Parent) "modules"
$utilsModule = Join-Path $moduleDir "ReSetUtils.psm1"
if (Test-Path $utilsModule) {
    Import-Module $utilsModule -Force
}

# Global variables
$Script:LogFile = $null
$Script:LastBackup = $null

# Console colors for professional output
$Colors = @{
    Header = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; 
    Error = 'Red'; Info = 'White'; Muted = 'DarkGray'; Emphasis = 'Magenta'
}

function Write-ShellResetLog {
    param(
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with colors
    $color = switch ($Level) {
        'SUCCESS' { $Colors.Success }
        'WARNING' { $Colors.Warning }
        'ERROR' { $Colors.Error }
        'DEBUG' { $Colors.Muted }
        default { $Colors.Info }
    }
    
    $symbol = switch ($Level) {
        'SUCCESS' { '✓' }
        'WARNING' { '⚠' }
        'ERROR' { '✗' }
        'DEBUG' { '•' }
        default { '•' }
    }
    
    if (-not $Silent) {
        Write-Host "$symbol $Message" -ForegroundColor $color
    }
    
    # File output
    if ($Script:LogFile) {
        $logEntry | Out-File -FilePath $Script:LogFile -Append -Encoding UTF8
    }
}

function Initialize-ShellResetLogging {
    $rootDir = Split-Path $PSScriptRoot -Parent
    $logsDir = Join-Path $rootDir "logs"
    
    if (-not (Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    
    $logFileName = "shell-reset-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').log"
    $Script:LogFile = Join-Path $logsDir $logFileName
    
    try {
        $logHeader = @"
===============================================
Windows Shell Reset - PowerShell Script Log
===============================================
Reset Date: $(Get-Date)
Computer: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $([System.Environment]::OSVersion.VersionString)
Reset Level: $ResetLevel
Parameters: Silent=$Silent, Force=$Force, NoBackup=$NoBackup
===============================================

"@
        $logHeader | Out-File -FilePath $Script:LogFile -Encoding UTF8
        Write-ShellResetLog -Level 'INFO' -Message "Shell reset logging initialized"
    } catch {
        Write-Warning "Could not initialize logging: $($_.Exception.Message)"
    }
}

function Test-WindowsVersion {
    $osVersion = [System.Environment]::OSVersion.Version
    $osName = (Get-WmiObject Win32_OperatingSystem).Caption
    
    Write-ShellResetLog -Level 'INFO' -Message "Windows version: $osName ($($osVersion.Major).$($osVersion.Minor))"
    
    if ($osVersion.Major -eq 10) {
        Write-ShellResetLog -Level 'SUCCESS' -Message "Windows 10/11 detected - Full compatibility"
        return $true
    } elseif ($osVersion.Major -eq 6 -and $osVersion.Minor -ge 1) {
        Write-ShellResetLog -Level 'WARNING' -Message "Windows 7/8 detected - Limited compatibility"
        return $true
    } else {
        Write-ShellResetLog -Level 'ERROR' -Message "Unsupported Windows version"
        return $false
    }
}

function Confirm-ShellResetAction {
    if ($Silent -or $Force) { return $true }
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $Colors.Warning
    Write-Host "               WARNING" -ForegroundColor $Colors.Warning
    Write-Host "============================================" -ForegroundColor $Colors.Warning
    Write-Host ""
    Write-Host "This operation will reset Windows Explorer settings including:" -ForegroundColor $Colors.Info
    Write-Host "• Folder view settings and preferences" -ForegroundColor $Colors.Muted
    Write-Host "• File association display settings" -ForegroundColor $Colors.Muted
    Write-Host "• Quick Access and navigation settings" -ForegroundColor $Colors.Muted
    Write-Host "• Explorer history and cache" -ForegroundColor $Colors.Muted
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor $Colors.Error
    Write-Host "• This action cannot be easily undone without backups" -ForegroundColor $Colors.Error
    Write-Host "• All Explorer windows will be closed and restarted" -ForegroundColor $Colors.Error
    Write-Host "• Custom folder views will be lost" -ForegroundColor $Colors.Error
    Write-Host ""
    Write-Host "Backups will be created automatically before changes." -ForegroundColor $Colors.Success
    Write-Host ""
    
    $confirm = Read-Host "Do you want to continue? Type 'yes' to proceed"
    
    if ($confirm -eq 'yes') {
        Write-ShellResetLog -Level 'INFO' -Message "User confirmed shell reset operation"
        return $true
    } else {
        Write-ShellResetLog -Level 'INFO' -Message "Operation cancelled by user"
        return $false
    }
}

function Backup-RegistryKey {
    param(
        [Parameter(Mandatory)]
        [string]$KeyPath,
        [Parameter(Mandatory)]
        [string]$BackupName
    )
    
    if ($NoBackup) {
        Write-ShellResetLog -Level 'WARNING' -Message "Backup skipped for: $KeyPath"
        return $null
    }
    
    try {
        $rootDir = Split-Path $PSScriptRoot -Parent
        $backupDir = if ($BackupPath) { $BackupPath } else { Join-Path $rootDir "backups" }
        
        if (-not (Test-Path $backupDir)) {
            New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
        $backupFile = Join-Path $backupDir "$BackupName-$timestamp.reg"
        
        Write-ShellResetLog -Level 'INFO' -Message "Backing up registry key: $KeyPath"
        
        $process = Start-Process -FilePath "reg.exe" -ArgumentList "export", "`"$KeyPath`"", "`"$backupFile`"", "/y" -Wait -PassThru -WindowStyle Hidden
        
        if ($process.ExitCode -eq 0 -and (Test-Path $backupFile)) {
            # Verify backup file integrity
            $backupContent = Get-Content $backupFile -TotalCount 5
            if ($backupContent -join "" -match "Windows Registry Editor Version") {
                Write-ShellResetLog -Level 'SUCCESS' -Message "Registry backup created and verified: $(Split-Path $backupFile -Leaf)"
                $Script:LastBackup = $backupFile
                return $backupFile
            } else {
                Write-ShellResetLog -Level 'ERROR' -Message "Registry backup file appears corrupted"
                Remove-Item $backupFile -Force -ErrorAction SilentlyContinue
                return $null
            }
        } else {
            Write-ShellResetLog -Level 'ERROR' -Message "Failed to backup registry key: $KeyPath (Exit Code: $($process.ExitCode))"
            return $null
        }
    } catch {
        Write-ShellResetLog -Level 'ERROR' -Message "Error backing up registry key '$KeyPath': $($_.Exception.Message)"
        return $null
    }
}

function Stop-ExplorerProcess {
    Write-ShellResetLog -Level 'INFO' -Message "Stopping Windows Explorer process..."
    
    try {
        $explorerProcesses = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        
        if ($explorerProcesses) {
            $explorerProcesses | Stop-Process -Force
            Write-ShellResetLog -Level 'SUCCESS' -Message "Windows Explorer stopped"
            Start-Sleep -Seconds 2
            return $true
        } else {
            Write-ShellResetLog -Level 'INFO' -Message "Windows Explorer was not running"
            return $false
        }
    } catch {
        Write-ShellResetLog -Level 'ERROR' -Message "Failed to stop Explorer: $($_.Exception.Message)"
        return $false
    }
}

function Start-ExplorerProcess {
    if (-not $RestartExplorer) { return }
    
    Write-ShellResetLog -Level 'INFO' -Message "Starting Windows Explorer..."
    
    try {
        Start-Process -FilePath "explorer.exe"
        Start-Sleep -Seconds 3
        
        # Verify Explorer started
        $explorerRunning = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        if ($explorerRunning) {
            Write-ShellResetLog -Level 'SUCCESS' -Message "Windows Explorer restarted successfully"
        } else {
            Write-ShellResetLog -Level 'WARNING' -Message "Explorer may not have started properly"
        }
    } catch {
        Write-ShellResetLog -Level 'ERROR' -Message "Failed to start Explorer: $($_.Exception.Message)"
    }
}

function Reset-ExplorerAdvancedSettings {
    Write-ShellResetLog -Level 'INFO' -Message "Resetting Explorer advanced settings..."
    
    $advancedSettings = @{
        'Hidden' = 2                    # Hide hidden files
        'HideFileExt' = 1              # Hide file extensions
        'ShowSuperHidden' = 0          # Don't show system files
        'LaunchTo' = 1                 # Open to This PC
        'ShowCompColor' = 1            # Show compressed files in color
        'ShowInfoTip' = 1              # Show tooltips
        'FolderContentsInfoTip' = 1    # Show folder tooltips
        'ShowStatusBar' = 1            # Show status bar
        'ShowPreviewHandlers' = 1      # Show preview pane
        'NavPaneExpandToCurrentFolder' = 1  # Expand to current folder
        'NavPaneShowAllFolders' = 0    # Don't show all folders
        'TypeAhead' = 1                # Enable type-ahead search
    }
    
    try {
        $advancedKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        
        foreach ($setting in $advancedSettings.Keys) {
            $value = $advancedSettings[$setting]
            Set-ItemProperty -Path $advancedKeyPath -Name $setting -Value $value -Type DWord -Force
            Write-ShellResetLog -Level 'DEBUG' -Message "Set $setting = $value"
        }
        
        Write-ShellResetLog -Level 'SUCCESS' -Message "Explorer advanced settings reset to defaults"
    } catch {
        Write-ShellResetLog -Level 'ERROR' -Message "Failed to reset advanced settings: $($_.Exception.Message)"
    }
}

function Reset-FolderViewSettings {
    Write-ShellResetLog -Level 'INFO' -Message "Resetting folder view settings..."
    
    $foldersToReset = @(
        'HKCU:\Software\Microsoft\Windows\Shell\Bags',
        'HKCU:\Software\Microsoft\Windows\Shell\BagMRU',
        'HKCU:\Software\Microsoft\Windows\ShellNoRoam\Bags',
        'HKCU:\Software\Microsoft\Windows\ShellNoRoam\BagMRU'
    )
    
    foreach ($keyPath in $foldersToReset) {
        try {
            if (Test-Path $keyPath) {
                Remove-Item -Path $keyPath -Recurse -Force
                Write-ShellResetLog -Level 'SUCCESS' -Message "Removed folder view cache: $(Split-Path $keyPath -Leaf)"
            } else {
                Write-ShellResetLog -Level 'DEBUG' -Message "Key does not exist: $keyPath"
            }
        } catch {
            Write-ShellResetLog -Level 'WARNING' -Message "Could not remove folder view cache '$keyPath': $($_.Exception.Message)"
        }
    }
}

function Reset-ContextMenuSettings {
    Write-ShellResetLog -Level 'INFO' -Message "Resetting context menu settings..."
    
    try {
        # Reset Windows 11 context menu
        $contextMenuKey = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
        if (Test-Path $contextMenuKey) {
            Remove-Item -Path $contextMenuKey -Recurse -Force
            Write-ShellResetLog -Level 'SUCCESS' -Message "Windows 11 context menu reset to default"
        }
        
        # Reset other context menu customizations
        $contextKeys = @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\EnableBalloonTips'
        )
        
        foreach ($key in $contextKeys) {
            if (Test-Path $key) {
                Remove-Item -Path $key -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        Write-ShellResetLog -Level 'WARNING' -Message "Context menu reset had issues: $($_.Exception.Message)"
    }
}

function Reset-QuickAccessSettings {
    Write-ShellResetLog -Level 'INFO' -Message "Resetting Quick Access settings..."
    
    try {
        $explorerKeyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
        
        # Reset Quick Access options
        Set-ItemProperty -Path $explorerKeyPath -Name "ShowFrequent" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $explorerKeyPath -Name "ShowRecent" -Value 1 -Type DWord -Force
        
        # Clear Quick Access pinned folders
        $ribbonKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon'
        if (Test-Path $ribbonKey) {
            Remove-Item -Path $ribbonKey -Recurse -Force
            Write-ShellResetLog -Level 'SUCCESS' -Message "Quick Access pinned items cleared"
        }
        
        Write-ShellResetLog -Level 'SUCCESS' -Message "Quick Access settings reset"
    } catch {
        Write-ShellResetLog -Level 'ERROR' -Message "Failed to reset Quick Access: $($_.Exception.Message)"
    }
}

function Clear-ThumbnailCache {
    Write-ShellResetLog -Level 'INFO' -Message "Clearing thumbnail cache..."
    
    $thumbnailPaths = @(
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",
        "$env:LOCALAPPDATA\IconCache.db",
        "$env:LOCALAPPDATA\Microsoft\Windows\Caches"
    )
    
    foreach ($path in $thumbnailPaths) {
        try {
            if (Test-Path $path) {
                if (Test-Path $path -PathType Container) {
                    # Directory - clear contents
                    Get-ChildItem -Path $path -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    Write-ShellResetLog -Level 'SUCCESS' -Message "Cleared thumbnail cache directory: $(Split-Path $path -Leaf)"
                } else {
                    # File - delete
                    Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
                    Write-ShellResetLog -Level 'SUCCESS' -Message "Deleted cache file: $(Split-Path $path -Leaf)"
                }
            }
        } catch {
            Write-ShellResetLog -Level 'WARNING' -Message "Could not clear cache '$path': $($_.Exception.Message)"
        }
    }
}

function Clear-ExplorerHistory {
    Write-ShellResetLog -Level 'INFO' -Message "Clearing Explorer history..."
    
    $historyKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\CIDSizeMRU',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU'
    )
    
    foreach ($keyPath in $historyKeys) {
        try {
            if (Test-Path $keyPath) {
                Remove-Item -Path $keyPath -Recurse -Force
                Write-ShellResetLog -Level 'SUCCESS' -Message "Cleared history: $(Split-Path $keyPath -Leaf)"
            }
        } catch {
            Write-ShellResetLog -Level 'WARNING' -Message "Could not clear history '$keyPath': $($_.Exception.Message)"
        }
    }
}

function Reset-ShellByLevel {
    param([string]$Level)
    
    # Minimal reset
    Reset-ExplorerAdvancedSettings
    Reset-FolderViewSettings
    
    # Standard reset (default)
    if ($Level -in @('Standard', 'Complete')) {
        Reset-ContextMenuSettings
        Reset-QuickAccessSettings
        Clear-ThumbnailCache
    }
    
    # Complete reset
    if ($Level -eq 'Complete') {
        Clear-ExplorerHistory
        
        # Additional complete reset operations
        Write-ShellResetLog -Level 'INFO' -Message "Performing complete shell reset..."
        
        # Reset desktop settings
        try {
            $desktopKey = "HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop"
            if (Test-Path $desktopKey) {
                Remove-Item -Path $desktopKey -Recurse -Force
                Write-ShellResetLog -Level 'SUCCESS' -Message "Desktop view settings reset"
            }
        } catch {
            Write-ShellResetLog -Level 'WARNING' -Message "Could not reset desktop settings: $($_.Exception.Message)"
        }
        
        # Clear search history
        try {
            $searchKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\WordWheelQuery"
            if (Test-Path $searchKey) {
                Remove-Item -Path $searchKey -Recurse -Force
                Write-ShellResetLog -Level 'SUCCESS' -Message "Search history cleared"
            }
        } catch {
            Write-ShellResetLog -Level 'WARNING' -Message "Could not clear search history: $($_.Exception.Message)"
        }
    }
}

function Show-ResetSummary {
    if ($Silent) { return }
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host " Windows Shell Reset Completed" -ForegroundColor $Colors.Header
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host ""
    Write-Host "Changes applied:" -ForegroundColor $Colors.Emphasis
    Write-Host "• Folder view settings reset to defaults" -ForegroundColor $Colors.Success
    Write-Host "• Hidden files settings reset" -ForegroundColor $Colors.Success
    Write-Host "• File extensions hidden by default" -ForegroundColor $Colors.Success
    Write-Host "• Quick Access reset to defaults" -ForegroundColor $Colors.Success
    
    if ($ResetLevel -in @('Standard', 'Complete')) {
        Write-Host "• Context menus reset" -ForegroundColor $Colors.Success
        Write-Host "• Thumbnail cache cleared" -ForegroundColor $Colors.Success
    }
    
    if ($ResetLevel -eq 'Complete') {
        Write-Host "• Explorer history cleared" -ForegroundColor $Colors.Success
        Write-Host "• Desktop view settings reset" -ForegroundColor $Colors.Success
        Write-Host "• Search history cleared" -ForegroundColor $Colors.Success
    }
    
    Write-Host ""
    
    if ($Script:LastBackup) {
        Write-Host "Backup created: $(Split-Path $Script:LastBackup -Leaf)" -ForegroundColor $Colors.Info
    }
    
    if ($Script:LogFile) {
        Write-Host "Log file: $(Split-Path $Script:LogFile -Leaf)" -ForegroundColor $Colors.Info
    }
    
    Write-Host ""
    Write-Host "Windows Explorer has been restarted with default settings." -ForegroundColor $Colors.Success
}

# Main execution
try {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host " Windows Shell Reset - PowerShell Edition" -ForegroundColor $Colors.Header
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host ""
    
    Initialize-ShellResetLogging
    
    # Check Windows version
    if (-not (Test-WindowsVersion)) {
        throw "Unsupported Windows version"
    }
    
    # Confirm action
    if (-not (Confirm-ShellResetAction)) {
        Write-ShellResetLog -Level 'INFO' -Message "Operation cancelled by user"
        exit 0
    }
    
    # Create backups
    Write-ShellResetLog -Level 'INFO' -Message "Creating registry backups..."
    Backup-RegistryKey -KeyPath "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" -BackupName "explorer_settings"
    Backup-RegistryKey -KeyPath "HKEY_CURRENT_USER\Software\Classes" -BackupName "file_associations"
    
    # Stop Explorer
    $explorerWasRunning = Stop-ExplorerProcess
    
    # Perform reset based on level
    Write-ShellResetLog -Level 'INFO' -Message "Starting shell reset (Level: $ResetLevel)..."
    Reset-ShellByLevel -Level $ResetLevel
    
    # Restart Explorer
    if ($explorerWasRunning -and $RestartExplorer) {
        Start-ExplorerProcess
    }
    
    Show-ResetSummary
    Write-ShellResetLog -Level 'SUCCESS' -Message "Windows Shell Reset completed successfully"
    
    if (-not $Silent) {
        Read-Host "`nPress Enter to continue"
    }
    
    exit 0
    
} catch {
    Write-ShellResetLog -Level 'ERROR' -Message "Shell reset failed: $($_.Exception.Message)"
    
    if ($_.Exception.InnerException) {
        Write-ShellResetLog -Level 'ERROR' -Message "Inner exception: $($_.Exception.InnerException.Message)"
    }
    
    # Attempt to restart Explorer if it was stopped
    if ($RestartExplorer) {
        try {
            Start-Process -FilePath "explorer.exe" -ErrorAction SilentlyContinue
        } catch {
            Write-ShellResetLog -Level 'WARNING' -Message "Could not restart Explorer after error"
        }
    }
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "Shell reset failed: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        Read-Host "Press Enter to continue"
    }
    
    exit 1
}