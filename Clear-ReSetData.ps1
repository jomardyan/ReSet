# ReSet Toolkit - PowerShell Cleanup System
# Automatically cleans old backups, logs, and temporary files with enhanced functionality

[CmdletBinding()]
param(
    [int]$LogRetentionDays = 30,
    [int]$BackupRetentionDays = 30,
    [int]$TempRetentionDays = 7,
    [switch]$Silent,
    [switch]$Force,
    [switch]$CompressOldBackups,
    [switch]$DryRun,
    [string]$ConfigPath = $null,
    [ValidateSet('Low', 'Medium', 'High', 'Maximum')]
    [string]$CleanupLevel = 'Medium'
)

#Requires -Version 5.0

# Enhanced error handling and strict mode
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import utilities if available
$moduleDir = Join-Path $PSScriptRoot "modules"
$utilsModule = Join-Path $moduleDir "ReSetUtils.psm1"
if (Test-Path $utilsModule) {
    Import-Module $utilsModule -Force
}

# Global variables
$Script:FilesDeleted = 0
$Script:SpaceFreed = 0
$Script:Errors = 0
$Script:LogFile = $null
$Script:StartTime = Get-Date

# Console colors for professional output
$Colors = @{
    Header = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; 
    Error = 'Red'; Info = 'White'; Muted = 'DarkGray'; Emphasis = 'Magenta'
}

function Write-CleanupHeader {
    if ($Silent) { return }
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host " ReSet Toolkit PowerShell Cleanup System" -ForegroundColor $Colors.Header
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host ""
}

function Write-CleanupLog {
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

function Initialize-CleanupLogging {
    $rootDir = Split-Path $PSScriptRoot -Parent
    $logsDir = Join-Path $rootDir "logs"
    
    if (-not (Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    
    $logFileName = "cleanup-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').log"
    $Script:LogFile = Join-Path $logsDir $logFileName
    
    try {
        $logHeader = @"
===============================================
ReSet Toolkit PowerShell Cleanup System Log
===============================================
Cleanup Date: $(Get-Date)
Computer: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
Cleanup Level: $CleanupLevel
Parameters: LogRetention=$LogRetentionDays, BackupRetention=$BackupRetentionDays, TempRetention=$TempRetentionDays
===============================================

"@
        $logHeader | Out-File -FilePath $Script:LogFile -Encoding UTF8
        Write-CleanupLog -Level 'INFO' -Message "Cleanup logging initialized"
    } catch {
        Write-Warning "Could not initialize cleanup logging: $($_.Exception.Message)"
    }
}

function Get-ReSetConfiguration {
    $rootDir = Split-Path $PSScriptRoot -Parent
    $configFile = if ($ConfigPath) { $ConfigPath } else { Join-Path $rootDir "config.ini" }
    
    $config = @{
        LogRetentionDays = $LogRetentionDays
        BackupRetentionDays = $BackupRetentionDays
        TempRetentionDays = $TempRetentionDays
        CompressionEnabled = $CompressOldBackups.IsPresent
        MaxBackupSize = "500MB"
        AutoCleanup = $true
        VerifyBackups = $true
    }
    
    if (Test-Path $configFile) {
        try {
            $configContent = Get-Content $configFile
            $currentSection = ""
            
            foreach ($line in $configContent) {
                $line = $line.Trim()
                if ($line -match '^\[(.+)\]$') {
                    $currentSection = $matches[1]
                } elseif ($line -match '^(.+?)=(.*)$' -and $currentSection -eq 'Backup') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
                    switch ($key) {
                        'CompressionEnabled' { $config.CompressionEnabled = $value -eq 'true' }
                        'RetentionDays' { $config.BackupRetentionDays = [int]$value }
                        'MaxBackupSize' { $config.MaxBackupSize = $value }
                        'AutoCleanup' { $config.AutoCleanup = $value -eq 'true' }
                        'VerifyBackups' { $config.VerifyBackups = $value -eq 'true' }
                    }
                } elseif ($line -match '^(.+?)=(.*)$' -and $currentSection -eq 'Advanced') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
                    if ($key -eq 'BackupRetentionDays') {
                        $config.BackupRetentionDays = [int]$value
                    }
                }
            }
            
            Write-CleanupLog -Level 'SUCCESS' -Message "Configuration loaded from: $(Split-Path $configFile -Leaf)"
        } catch {
            Write-CleanupLog -Level 'WARNING' -Message "Could not read configuration file: $($_.Exception.Message)"
        }
    } else {
        Write-CleanupLog -Level 'INFO' -Message "Using default configuration (no config file found)"
    }
    
    return $config
}

function Get-FileAgeInDays {
    param([string]$FilePath)
    
    try {
        $fileInfo = Get-Item $FilePath
        $age = (Get-Date) - $fileInfo.CreationTime
        return [math]::Floor($age.TotalDays)
    } catch {
        return 0
    }
}

function Remove-OldFiles {
    param(
        [string]$CleanupDir,
        [int]$RetentionDays,
        [string]$FilePattern = "*.*",
        [string]$Description = "files"
    )
    
    if (-not (Test-Path $CleanupDir)) {
        Write-CleanupLog -Level 'INFO' -Message "Directory does not exist: $CleanupDir"
        return
    }
    
    Write-CleanupLog -Level 'INFO' -Message "Cleaning $Description older than $RetentionDays days in $CleanupDir..."
    
    $localDeleted = 0
    $localSpaceFreed = 0
    
    try {
        $files = Get-ChildItem -Path $CleanupDir -Filter $FilePattern -File -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            $age = Get-FileAgeInDays -FilePath $file.FullName
            
            if ($age -gt $RetentionDays) {
                $fileSize = $file.Length
                
                if ($DryRun) {
                    Write-CleanupLog -Level 'DEBUG' -Message "[DRY RUN] Would delete: $($file.Name) (age: $age days, size: $([math]::Round($fileSize/1024, 2)) KB)"
                    $localDeleted++
                    $localSpaceFreed += $fileSize
                } else {
                    try {
                        Remove-Item -Path $file.FullName -Force
                        Write-CleanupLog -Level 'SUCCESS' -Message "Deleted: $($file.Name) (age: $age days, size: $([math]::Round($fileSize/1024, 2)) KB)"
                        $localDeleted++
                        $localSpaceFreed += $fileSize
                    } catch {
                        Write-CleanupLog -Level 'ERROR' -Message "Failed to delete: $($file.Name) - $($_.Exception.Message)"
                        $Script:Errors++
                    }
                }
            }
        }
        
        if ($localDeleted -eq 0) {
            Write-CleanupLog -Level 'INFO' -Message "No old $Description found to clean"
        } else {
            $spaceFreedMB = [math]::Round($localSpaceFreed / 1MB, 2)
            Write-CleanupLog -Level 'SUCCESS' -Message "Cleaned $localDeleted $Description files ($spaceFreedMB MB)"
            $Script:FilesDeleted += $localDeleted
            $Script:SpaceFreed += $localSpaceFreed
        }
    } catch {
        Write-CleanupLog -Level 'ERROR' -Message "Error cleaning $Description : $($_.Exception.Message)"
        $Script:Errors++
    }
}

function Remove-EmptyDirectories {
    param(
        [string]$CleanupDir,
        [string]$Description = "directory"
    )
    
    if (-not (Test-Path $CleanupDir)) { return }
    
    Write-CleanupLog -Level 'INFO' -Message "Checking for empty directories in $Description..."
    
    try {
        $emptyDirs = Get-ChildItem -Path $CleanupDir -Directory -Recurse | 
                     Where-Object { (Get-ChildItem $_.FullName -Force).Count -eq 0 } |
                     Sort-Object FullName -Descending
        
        foreach ($dir in $emptyDirs) {
            if ($DryRun) {
                Write-CleanupLog -Level 'DEBUG' -Message "[DRY RUN] Would remove empty directory: $($dir.Name)"
            } else {
                try {
                    Remove-Item -Path $dir.FullName -Force
                    Write-CleanupLog -Level 'SUCCESS' -Message "Removed empty directory: $($dir.Name)"
                } catch {
                    Write-CleanupLog -Level 'ERROR' -Message "Failed to remove directory: $($dir.Name) - $($_.Exception.Message)"
                    $Script:Errors++
                }
            }
        }
    } catch {
        Write-CleanupLog -Level 'ERROR' -Message "Error checking empty directories: $($_.Exception.Message)"
        $Script:Errors++
    }
}

function Test-RegistryBackupIntegrity {
    param([string]$BackupFile)
    
    try {
        $content = Get-Content -Path $BackupFile -TotalCount 5
        return ($content -join "" -match "Windows Registry Editor Version")
    } catch {
        return $false
    }
}

function Remove-CorruptedBackups {
    param([string]$BackupDir)
    
    if (-not (Test-Path $BackupDir)) { return }
    
    Write-CleanupLog -Level 'INFO' -Message "Checking for corrupted backup files..."
    
    $regBackups = Get-ChildItem -Path $BackupDir -Filter "*.reg" -File -ErrorAction SilentlyContinue
    
    foreach ($backup in $regBackups) {
        if (-not (Test-RegistryBackupIntegrity -BackupFile $backup.FullName)) {
            if ($DryRun) {
                Write-CleanupLog -Level 'DEBUG' -Message "[DRY RUN] Would remove corrupted backup: $($backup.Name)"
            } else {
                try {
                    Remove-Item -Path $backup.FullName -Force
                    Write-CleanupLog -Level 'SUCCESS' -Message "Removed corrupted registry backup: $($backup.Name)"
                    $Script:FilesDeleted++
                } catch {
                    Write-CleanupLog -Level 'ERROR' -Message "Failed to remove corrupted backup: $($backup.Name)"
                    $Script:Errors++
                }
            }
        }
    }
}

function Compress-OldBackups {
    param(
        [string]$BackupDir,
        [int]$CompressAfterDays = 7
    )
    
    if (-not (Test-Path $BackupDir)) { return }
    
    Write-CleanupLog -Level 'INFO' -Message "Compressing old backup files (older than $CompressAfterDays days)..."
    
    $files = Get-ChildItem -Path $BackupDir -File | Where-Object { $_.Extension -ne '.zip' }
    
    foreach ($file in $files) {
        $age = Get-FileAgeInDays -FilePath $file.FullName
        
        if ($age -gt $CompressAfterDays) {
            $zipPath = "$($file.FullName).zip"
            
            if ($DryRun) {
                Write-CleanupLog -Level 'DEBUG' -Message "[DRY RUN] Would compress: $($file.Name)"
                continue
            }
            
            try {
                Compress-Archive -Path $file.FullName -DestinationPath $zipPath -Force
                
                # Verify compression successful
                if (Test-Path $zipPath) {
                    $originalSize = $file.Length
                    $compressedSize = (Get-Item $zipPath).Length
                    $savedSpace = $originalSize - $compressedSize
                    
                    Remove-Item -Path $file.FullName -Force
                    Write-CleanupLog -Level 'SUCCESS' -Message "Compressed backup: $($file.Name) (saved $([math]::Round($savedSpace/1024, 2)) KB)"
                    $Script:SpaceFreed += $savedSpace
                } else {
                    Write-CleanupLog -Level 'ERROR' -Message "Compression failed for: $($file.Name)"
                    $Script:Errors++
                }
            } catch {
                Write-CleanupLog -Level 'ERROR' -Message "Error compressing $($file.Name): $($_.Exception.Message)"
                $Script:Errors++
            }
        }
    }
}

function Invoke-CleanupByLevel {
    param([string]$Level, [hashtable]$Config)
    
    $rootDir = Split-Path $PSScriptRoot -Parent
    
    # Base cleanup (all levels)
    Remove-OldFiles -CleanupDir (Join-Path $rootDir "logs") -RetentionDays $Config.LogRetentionDays -FilePattern "*.log" -Description "log files"
    Remove-OldFiles -CleanupDir (Join-Path $rootDir "backups") -RetentionDays $Config.BackupRetentionDays -FilePattern "*.*" -Description "backup files"
    
    # Medium and above
    if ($Level -in @('Medium', 'High', 'Maximum')) {
        Remove-OldFiles -CleanupDir (Join-Path $rootDir "temp") -RetentionDays $Config.TempRetentionDays -FilePattern "*.*" -Description "temporary files"
        Remove-OldFiles -CleanupDir $env:TEMP -RetentionDays 1 -FilePattern "ReSet_*.*" -Description "ReSet temporary files"
        Remove-OldFiles -CleanupDir (Join-Path $rootDir "logs") -RetentionDays 14 -FilePattern "validation-*.log" -Description "validation logs"
        Remove-CorruptedBackups -BackupDir (Join-Path $rootDir "backups")
    }
    
    # High and above
    if ($Level -in @('High', 'Maximum')) {
        Remove-OldFiles -CleanupDir (Join-Path $rootDir "logs") -RetentionDays 30 -FilePattern "installation-*.log" -Description "installation logs"
        Remove-EmptyDirectories -CleanupDir (Join-Path $rootDir "backups") -Description "backup directory"
        Remove-EmptyDirectories -CleanupDir (Join-Path $rootDir "temp") -Description "temp directory"
        
        if ($Config.CompressionEnabled) {
            Compress-OldBackups -BackupDir (Join-Path $rootDir "backups")
        }
    }
    
    # Maximum cleanup
    if ($Level -eq 'Maximum') {
        Remove-OldFiles -CleanupDir (Join-Path $rootDir "logs") -RetentionDays 7 -FilePattern "debug-*.log" -Description "debug logs"
        Remove-OldFiles -CleanupDir (Join-Path $rootDir "backups") -RetentionDays 7 -FilePattern "*.tmp" -Description "temporary backup files"
        
        # Clean Windows error reporting files
        $werDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\WER\ReportArchive"
        if (Test-Path $werDir) {
            Remove-OldFiles -CleanupDir $werDir -RetentionDays 3 -FilePattern "*ReSet*" -Description "Windows Error Reporting files"
        }
    }
}

function Show-CleanupResults {
    $duration = (Get-Date) - $Script:StartTime
    $spaceFreedMB = [math]::Round($Script:SpaceFreed / 1MB, 2)
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor $Colors.Header
        Write-Host " Cleanup Results" -ForegroundColor $Colors.Header
        Write-Host "============================================" -ForegroundColor $Colors.Header
        Write-Host ""
        Write-Host "Files processed: $($Script:FilesDeleted)" -ForegroundColor $Colors.Info
        Write-Host "Space freed: $spaceFreedMB MB" -ForegroundColor $Colors.Success
        Write-Host "Errors encountered: $($Script:Errors)" -ForegroundColor $(if ($Script:Errors -gt 0) { $Colors.Error } else { $Colors.Success })
        Write-Host "Duration: $([math]::Round($duration.TotalSeconds, 1)) seconds" -ForegroundColor $Colors.Info
        Write-Host "Cleanup level: $CleanupLevel" -ForegroundColor $Colors.Emphasis
        
        if ($DryRun) {
            Write-Host ""
            Write-Host "DRY RUN MODE - No files were actually deleted" -ForegroundColor $Colors.Warning
        }
        
        Write-Host ""
    }
    
    Write-CleanupLog -Level 'INFO' -Message "Cleanup completed: $($Script:FilesDeleted) files processed, $spaceFreedMB MB freed, $($Script:Errors) errors, duration: $([math]::Round($duration.TotalSeconds, 1))s"
    
    # Cleanup recommendations
    if ($Script:FilesDeleted -eq 0) {
        Write-CleanupLog -Level 'INFO' -Message "No cleanup was necessary - system is already clean"
    } elseif ($Script:FilesDeleted -lt 10) {
        Write-CleanupLog -Level 'INFO' -Message "Light cleanup performed - system maintenance is up to date"
    } else {
        Write-CleanupLog -Level 'INFO' -Message "Significant cleanup performed - consider running cleanup more frequently"
    }
    
    if ($Script:Errors -gt 0) {
        Write-CleanupLog -Level 'WARNING' -Message "$($Script:Errors) errors occurred during cleanup - check log for details"
        return 1
    } else {
        Write-CleanupLog -Level 'SUCCESS' -Message "Cleanup completed successfully"
        return 0
    }
}

# Main execution
try {
    Write-CleanupHeader
    
    if ($DryRun -and -not $Silent) {
        Write-Host "DRY RUN MODE - No files will be deleted" -ForegroundColor $Colors.Warning
        Write-Host ""
    }
    
    Initialize-CleanupLogging
    $config = Get-ReSetConfiguration
    
    if (-not $Silent) {
        Write-Host "Cleanup Configuration:" -ForegroundColor $Colors.Emphasis
        Write-Host "• Log retention: $($config.LogRetentionDays) days" -ForegroundColor $Colors.Info
        Write-Host "• Backup retention: $($config.BackupRetentionDays) days" -ForegroundColor $Colors.Info
        Write-Host "• Temp retention: $($config.TempRetentionDays) days" -ForegroundColor $Colors.Info
        Write-Host "• Cleanup level: $CleanupLevel" -ForegroundColor $Colors.Info
        Write-Host "• Compression: $(if ($config.CompressionEnabled) { 'Enabled' } else { 'Disabled' })" -ForegroundColor $Colors.Info
        Write-Host ""
    }
    
    if (-not $Force -and -not $Silent -and -not $DryRun) {
        $confirm = Read-Host "Proceed with cleanup? (Y/n)"
        if ($confirm -match '^n') {
            Write-CleanupLog -Level 'INFO' -Message "Cleanup cancelled by user"
            exit 0
        }
    }
    
    Write-CleanupLog -Level 'INFO' -Message "Starting $CleanupLevel level cleanup..."
    
    Invoke-CleanupByLevel -Level $CleanupLevel -Config $config
    
    $exitCode = Show-CleanupResults
    
    if (-not $Silent -and -not $DryRun) {
        Write-Host ""
        Read-Host "Press Enter to continue"
    }
    
    exit $exitCode
    
} catch {
    Write-CleanupLog -Level 'ERROR' -Message "Cleanup failed: $($_.Exception.Message)"
    
    if ($_.Exception.InnerException) {
        Write-CleanupLog -Level 'ERROR' -Message "Inner exception: $($_.Exception.InnerException.Message)"
    }
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "Cleanup failed: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        Read-Host "Press Enter to continue"
    }
    
    exit 1
}