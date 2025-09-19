# Windows Settings Reset Toolkit - PowerShell Backup Restore Utility
# Restores system settings from previously created backups with enhanced functionality

[CmdletBinding(DefaultParameterSetName = 'Interactive')]
param(
    [Parameter(ParameterSetName = 'Specific')]
    [string]$Date,
    
    [Parameter(ParameterSetName = 'Specific')]
    [string]$Category,
    
    [Parameter(ParameterSetName = 'List')]
    [switch]$ListBackups,
    
    [Parameter(ParameterSetName = 'RestoreAll')]
    [switch]$RestoreAll,
    
    [string]$BackupPath = $null,
    [switch]$Silent,
    [switch]$Force,
    [switch]$NoRestart,
    [switch]$VerifyBeforeRestore,
    [ValidateSet('Low', 'Medium', 'High')]
    [string]$ValidationLevel = 'Medium'
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
$Script:BackupsRestored = 0
$Script:RestorationErrors = 0

# Console colors for professional output
$Colors = @{
    Header = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; 
    Error = 'Red'; Info = 'White'; Muted = 'DarkGray'; Emphasis = 'Magenta'
}

function Write-RestoreLog {
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

function Initialize-RestoreLogging {
    $rootDir = Split-Path $PSScriptRoot -Parent
    $logsDir = Join-Path $rootDir "logs"
    
    if (-not (Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    
    $logFileName = "backup-restore-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').log"
    $Script:LogFile = Join-Path $logsDir $logFileName
    
    try {
        $logHeader = @"
===============================================
Backup Restore Utility - PowerShell Script Log
===============================================
Restore Date: $(Get-Date)
Computer: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
Parameters: Date=$Date, Category=$Category, ListBackups=$ListBackups, RestoreAll=$RestoreAll
===============================================

"@
        $logHeader | Out-File -FilePath $Script:LogFile -Encoding UTF8
        Write-RestoreLog -Level 'INFO' -Message "Backup restore logging initialized"
    } catch {
        Write-Warning "Could not initialize restore logging: $($_.Exception.Message)"
    }
}

function Get-BackupDirectory {
    if ($BackupPath) {
        return $BackupPath
    }
    
    $rootDir = Split-Path $PSScriptRoot -Parent
    return Join-Path $rootDir "backups"
}

function Get-AvailableBackups {
    $backupDir = Get-BackupDirectory
    
    if (-not (Test-Path $backupDir)) {
        Write-RestoreLog -Level 'WARNING' -Message "Backup directory does not exist: $backupDir"
        return @()
    }
    
    $backups = @{
        FolderBackups = @()
        RegistryBackups = @()
    }
    
    # Get folder backups
    try {
        $folderBackups = Get-ChildItem -Path $backupDir -Directory -ErrorAction SilentlyContinue
        foreach ($backup in $folderBackups) {
            $backupInfo = [PSCustomObject]@{
                Name = $backup.Name
                FullPath = $backup.FullName
                Date = $backup.CreationTime
                Size = (Get-ChildItem -Path $backup.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
                Type = 'Folder'
                Category = ($backup.Name -split '_')[0]
                BackupDate = if ($backup.Name -match '\d{4}-\d{2}-\d{2}') { $matches[0] } else { 'Unknown' }
            }
            $backups.FolderBackups += $backupInfo
        }
    } catch {
        Write-RestoreLog -Level 'WARNING' -Message "Error scanning folder backups: $($_.Exception.Message)"
    }
    
    # Get registry backups
    try {
        $regBackups = Get-ChildItem -Path $backupDir -Filter "*.reg" -ErrorAction SilentlyContinue
        foreach ($backup in $regBackups) {
            $backupInfo = [PSCustomObject]@{
                Name = $backup.Name
                FullPath = $backup.FullName
                Date = $backup.CreationTime
                Size = $backup.Length
                Type = 'Registry'
                Category = ($backup.BaseName -split '-')[0]
                BackupDate = if ($backup.Name -match '\d{4}-\d{2}-\d{2}') { $matches[0] } else { 'Unknown' }
            }
            $backups.RegistryBackups += $backupInfo
        }
    } catch {
        Write-RestoreLog -Level 'WARNING' -Message "Error scanning registry backups: $($_.Exception.Message)"
    }
    
    return $backups
}

function Show-AvailableBackups {
    if (-not $Silent) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor $Colors.Header
        Write-Host " Available Backups" -ForegroundColor $Colors.Header
        Write-Host "============================================" -ForegroundColor $Colors.Header
        Write-Host ""
    }
    
    $backups = Get-AvailableBackups
    
    if ($backups.FolderBackups.Count -eq 0 -and $backups.RegistryBackups.Count -eq 0) {
        Write-RestoreLog -Level 'INFO' -Message "No backups found in backup directory"
        return
    }
    
    # Group backups by date
    $allBackups = $backups.FolderBackups + $backups.RegistryBackups
    $groupedBackups = $allBackups | Group-Object BackupDate | Sort-Object Name -Descending
    
    foreach ($dateGroup in $groupedBackups) {
        $backupDate = $dateGroup.Name
        
        if (-not $Silent) {
            Write-Host ""
            Write-Host "Date: $backupDate" -ForegroundColor $Colors.Emphasis
            Write-Host "$(('-' * 50))" -ForegroundColor $Colors.Muted
        }
        
        Write-RestoreLog -Level 'INFO' -Message "Backups for date: $backupDate"
        
        foreach ($backup in ($dateGroup.Group | Sort-Object Category)) {
            $sizeDisplay = if ($backup.Size -gt 1MB) {
                "$([math]::Round($backup.Size / 1MB, 2)) MB"
            } elseif ($backup.Size -gt 1KB) {
                "$([math]::Round($backup.Size / 1KB, 2)) KB"
            } else {
                "$($backup.Size) bytes"
            }
            
            $typeSymbol = if ($backup.Type -eq 'Registry') { 'REG' } else { 'DIR' }
            
            if (-not $Silent) {
                Write-Host "  [$typeSymbol] $($backup.Category) - $sizeDisplay" -ForegroundColor $Colors.Info
            }
            
            Write-RestoreLog -Level 'DEBUG' -Message "Found backup: $($backup.Name) ($($backup.Type), $sizeDisplay)"
        }
    }
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "Total backups: $($allBackups.Count)" -ForegroundColor $Colors.Info
        Write-Host ""
    }
}

function Test-BackupIntegrity {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$BackupInfo
    )
    
    Write-RestoreLog -Level 'DEBUG' -Message "Validating backup integrity: $($BackupInfo.Name)"
    
    if ($BackupInfo.Type -eq 'Registry') {
        # Validate registry backup
        try {
            $content = Get-Content -Path $BackupInfo.FullPath -TotalCount 5
            $isValid = ($content -join "" -match "Windows Registry Editor Version")
            
            if ($isValid) {
                Write-RestoreLog -Level 'DEBUG' -Message "Registry backup validation passed: $($BackupInfo.Name)"
                return $true
            } else {
                Write-RestoreLog -Level 'WARNING' -Message "Registry backup appears corrupted: $($BackupInfo.Name)"
                return $false
            }
        } catch {
            Write-RestoreLog -Level 'ERROR' -Message "Error validating registry backup: $($_.Exception.Message)"
            return $false
        }
    } else {
        # Validate folder backup
        try {
            $files = Get-ChildItem -Path $BackupInfo.FullPath -Recurse -File -ErrorAction SilentlyContinue
            if ($files.Count -gt 0) {
                Write-RestoreLog -Level 'DEBUG' -Message "Folder backup validation passed: $($BackupInfo.Name) ($($files.Count) files)"
                return $true
            } else {
                Write-RestoreLog -Level 'WARNING' -Message "Folder backup appears empty: $($BackupInfo.Name)"
                return $false
            }
        } catch {
            Write-RestoreLog -Level 'ERROR' -Message "Error validating folder backup: $($_.Exception.Message)"
            return $false
        }
    }
}

function Restore-FolderBackup {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$BackupInfo
    )
    
    Write-RestoreLog -Level 'INFO' -Message "Restoring folder backup: $($BackupInfo.Name)"
    
    # Determine restore destination based on backup category
    $restoreDestination = switch ($BackupInfo.Category) {
        'desktop' { $env:USERPROFILE }
        'international' { $env:USERPROFILE }
        'theme' { $env:USERPROFILE }
        'wallpaper' { "$env:APPDATA\Microsoft\Windows\Themes" }
        'fonts' { "$env:WINDIR\Fonts" }
        default { 
            Write-RestoreLog -Level 'WARNING' -Message "Unknown backup category: $($BackupInfo.Category)"
            return $false
        }
    }
    
    if (-not (Test-Path $restoreDestination)) {
        try {
            New-Item -Path $restoreDestination -ItemType Directory -Force | Out-Null
            Write-RestoreLog -Level 'INFO' -Message "Created destination directory: $restoreDestination"
        } catch {
            Write-RestoreLog -Level 'ERROR' -Message "Could not create destination directory: $($_.Exception.Message)"
            return $false
        }
    }
    
    try {
        # Copy files from backup to destination
        $sourceFiles = Get-ChildItem -Path $BackupInfo.FullPath -Recurse -File
        $copiedFiles = 0
        
        foreach ($file in $sourceFiles) {
            $relativePath = $file.FullName.Substring($BackupInfo.FullPath.Length + 1)
            $destinationFile = Join-Path $restoreDestination $relativePath
            $destinationDir = Split-Path $destinationFile -Parent
            
            if (-not (Test-Path $destinationDir)) {
                New-Item -Path $destinationDir -ItemType Directory -Force | Out-Null
            }
            
            Copy-Item -Path $file.FullName -Destination $destinationFile -Force
            $copiedFiles++
        }
        
        Write-RestoreLog -Level 'SUCCESS' -Message "Folder backup restored: $($BackupInfo.Name) ($copiedFiles files)"
        return $true
    } catch {
        Write-RestoreLog -Level 'ERROR' -Message "Failed to restore folder backup: $($_.Exception.Message)"
        return $false
    }
}

function Restore-RegistryBackup {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$BackupInfo
    )
    
    Write-RestoreLog -Level 'INFO' -Message "Restoring registry backup: $($BackupInfo.Name)"
    
    try {
        $process = Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$($BackupInfo.FullPath)`"" -Wait -PassThru -WindowStyle Hidden
        
        if ($process.ExitCode -eq 0) {
            Write-RestoreLog -Level 'SUCCESS' -Message "Registry backup restored: $($BackupInfo.Name)"
            return $true
        } else {
            Write-RestoreLog -Level 'ERROR' -Message "Registry import failed for: $($BackupInfo.Name) (Exit Code: $($process.ExitCode))"
            return $false
        }
    } catch {
        Write-RestoreLog -Level 'ERROR' -Message "Error restoring registry backup: $($_.Exception.Message)"
        return $false
    }
}

function Restore-BackupsByFilter {
    param(
        [string]$DateFilter = $null,
        [string]$CategoryFilter = $null
    )
    
    $backups = Get-AvailableBackups
    $allBackups = $backups.FolderBackups + $backups.RegistryBackups
    
    # Apply filters
    if ($DateFilter) {
        $allBackups = $allBackups | Where-Object { $_.BackupDate -eq $DateFilter }
    }
    
    if ($CategoryFilter) {
        $allBackups = $allBackups | Where-Object { $_.Category -like "*$CategoryFilter*" }
    }
    
    if ($allBackups.Count -eq 0) {
        Write-RestoreLog -Level 'WARNING' -Message "No backups found matching the specified criteria"
        return 0
    }
    
    Write-RestoreLog -Level 'INFO' -Message "Found $($allBackups.Count) backups to restore"
    
    $restored = 0
    $errors = 0
    
    foreach ($backup in $allBackups) {
        # Validate backup if requested
        if ($VerifyBeforeRestore) {
            if (-not (Test-BackupIntegrity -BackupInfo $backup)) {
                Write-RestoreLog -Level 'WARNING' -Message "Skipping invalid backup: $($backup.Name)"
                $errors++
                continue
            }
        }
        
        # Restore backup
        $success = if ($backup.Type -eq 'Registry') {
            Restore-RegistryBackup -BackupInfo $backup
        } else {
            Restore-FolderBackup -BackupInfo $backup
        }
        
        if ($success) {
            $restored++
        } else {
            $errors++
        }
    }
    
    $Script:BackupsRestored += $restored
    $Script:RestorationErrors += $errors
    
    return $restored
}

function Show-InteractiveMenu {
    do {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor $Colors.Header
        Write-Host " Backup Restoration Options" -ForegroundColor $Colors.Header
        Write-Host "============================================" -ForegroundColor $Colors.Header
        Write-Host ""
        Write-Host "1. List all available backups" -ForegroundColor $Colors.Info
        Write-Host "2. Restore specific backup by date and category" -ForegroundColor $Colors.Info
        Write-Host "3. Restore all backups from a specific date" -ForegroundColor $Colors.Info
        Write-Host "4. Advanced restoration options" -ForegroundColor $Colors.Info
        Write-Host "5. Exit" -ForegroundColor $Colors.Info
        Write-Host ""
        
        $choice = Read-Host "Enter your choice (1-5)"
        
        switch ($choice) {
            '1' { 
                Show-AvailableBackups
                Read-Host "Press Enter to continue"
            }
            '2' { 
                $targetDate = Read-Host "Enter backup date (YYYY-MM-DD)"
                $targetCategory = Read-Host "Enter category (or leave blank for all)"
                
                if ($targetDate) {
                    $restored = Restore-BackupsByFilter -DateFilter $targetDate -CategoryFilter $targetCategory
                    Write-Host "Restored $restored backups" -ForegroundColor $Colors.Success
                }
            }
            '3' { 
                $targetDate = Read-Host "Enter backup date (YYYY-MM-DD)"
                if ($targetDate) {
                    Write-Host ""
                    Write-Host "WARNING: This will restore ALL backups from $targetDate" -ForegroundColor $Colors.Warning
                    $confirm = Read-Host "Type 'yes' to continue"
                    
                    if ($confirm -eq 'yes') {
                        $restored = Restore-BackupsByFilter -DateFilter $targetDate
                        Write-Host "Restored $restored backups" -ForegroundColor $Colors.Success
                    }
                }
            }
            '4' {
                Show-AdvancedOptions
            }
            '5' { return }
            default { 
                Write-Host "Invalid choice. Please try again." -ForegroundColor $Colors.Warning 
            }
        }
    } while ($true)
}

function Show-AdvancedOptions {
    Write-Host ""
    Write-Host "Advanced Restoration Options:" -ForegroundColor $Colors.Emphasis
    Write-Host "• Verification Level: $ValidationLevel" -ForegroundColor $Colors.Info
    Write-Host "• Verify Before Restore: $VerifyBeforeRestore" -ForegroundColor $Colors.Info
    Write-Host "• Force Mode: $Force" -ForegroundColor $Colors.Info
    Write-Host "• Auto Restart Explorer: $(-not $NoRestart)" -ForegroundColor $Colors.Info
    Write-Host ""
    
    $choice = Read-Host "Press Enter to continue"
}

function Request-ExplorerRestart {
    if ($NoRestart -or $Silent) { return }
    
    Write-Host ""
    Write-Host "Some changes may require restarting Windows Explorer." -ForegroundColor $Colors.Info
    $restart = Read-Host "Would you like to restart Explorer now? (y/N)"
    
    if ($restart -match '^(y|yes)$') {
        try {
            Write-RestoreLog -Level 'INFO' -Message "Restarting Windows Explorer as requested"
            Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Process -FilePath "explorer.exe"
            Write-RestoreLog -Level 'SUCCESS' -Message "Windows Explorer restarted"
        } catch {
            Write-RestoreLog -Level 'WARNING' -Message "Could not restart Explorer: $($_.Exception.Message)"
        }
    }
}

function Show-RestoreSummary {
    if ($Silent) { return }
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host " Restoration Summary" -ForegroundColor $Colors.Header
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host ""
    Write-Host "Backups restored: $($Script:BackupsRestored)" -ForegroundColor $Colors.Success
    Write-Host "Errors encountered: $($Script:RestorationErrors)" -ForegroundColor $(if ($Script:RestorationErrors -gt 0) { $Colors.Error } else { $Colors.Success })
    Write-Host ""
    
    if ($Script:BackupsRestored -gt 0) {
        Write-Host "IMPORTANT: Some changes may require:" -ForegroundColor $Colors.Warning
        Write-Host "• Signing out and signing back in" -ForegroundColor $Colors.Muted
        Write-Host "• Restarting Windows Explorer" -ForegroundColor $Colors.Muted
        Write-Host "• Restarting the computer" -ForegroundColor $Colors.Muted
        Write-Host ""
    }
    
    if ($Script:LogFile) {
        Write-Host "Log file: $(Split-Path $Script:LogFile -Leaf)" -ForegroundColor $Colors.Info
    }
}

# Main execution
try {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host " ReSet Toolkit - Backup Restore Utility" -ForegroundColor $Colors.Header
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host ""
    
    Initialize-RestoreLogging
    
    # Handle list backups
    if ($ListBackups) {
        Show-AvailableBackups
        exit 0
    }
    
    # Handle specific restore
    if ($Date) {
        Write-RestoreLog -Level 'INFO' -Message "Starting targeted backup restoration"
        $restored = Restore-BackupsByFilter -DateFilter $Date -CategoryFilter $Category
        
        if ($restored -eq 0) {
            Write-RestoreLog -Level 'WARNING' -Message "No backups were restored"
            exit 1
        }
    }
    # Handle restore all
    elseif ($RestoreAll) {
        if (-not $Date) {
            Write-RestoreLog -Level 'ERROR' -Message "RestoreAll requires a Date parameter"
            throw "RestoreAll parameter requires specifying a Date"
        }
        
        Write-RestoreLog -Level 'INFO' -Message "Starting full backup restoration for date: $Date"
        
        if (-not $Force -and -not $Silent) {
            Write-Host "WARNING: This will restore ALL backups from $Date" -ForegroundColor $Colors.Warning
            $confirm = Read-Host "Type 'yes' to continue"
            if ($confirm -ne 'yes') {
                Write-RestoreLog -Level 'INFO' -Message "Operation cancelled by user"
                exit 0
            }
        }
        
        $restored = Restore-BackupsByFilter -DateFilter $Date
        
        if ($restored -eq 0) {
            Write-RestoreLog -Level 'WARNING' -Message "No backups were restored"
            exit 1
        }
    }
    # Interactive mode
    else {
        Write-RestoreLog -Level 'INFO' -Message "Starting interactive backup restoration"
        Show-InteractiveMenu
    }
    
    Show-RestoreSummary
    
    if ($Script:BackupsRestored -gt 0) {
        Request-ExplorerRestart
    }
    
    Write-RestoreLog -Level 'SUCCESS' -Message "Backup restoration completed successfully"
    
    if (-not $Silent) {
        Read-Host "`nPress Enter to continue"
    }
    
    exit 0
    
} catch {
    Write-RestoreLog -Level 'ERROR' -Message "Backup restoration failed: $($_.Exception.Message)"
    
    if ($_.Exception.InnerException) {
        Write-RestoreLog -Level 'ERROR' -Message "Inner exception: $($_.Exception.InnerException.Message)"
    }
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "Backup restoration failed: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        Read-Host "Press Enter to continue"
    }
    
    exit 1
}