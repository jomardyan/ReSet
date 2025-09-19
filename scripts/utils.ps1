# Windows Settings Reset Toolkit - Utility Functions
# Common functions for logging, backup, and safety checks

param(
    [switch]$Silent,
    [switch]$VerifyBackup,
    [string]$BackupPath
)

# Initialize variables
if (-not $env:RESET_ROOT) { $env:RESET_ROOT = Split-Path $PSScriptRoot -Parent }
if (-not $env:LOG_DIR) { $env:LOG_DIR = Join-Path $env:RESET_ROOT "logs" }
if (-not $env:BACKUP_DIR) { $env:BACKUP_DIR = Join-Path $env:RESET_ROOT "backups" }

# Override backup directory if provided
if ($BackupPath) { $env:BACKUP_DIR = $BackupPath }

# Create directories if they don't exist
if (-not (Test-Path $env:LOG_DIR)) { New-Item -ItemType Directory -Path $env:LOG_DIR -Force | Out-Null }
if (-not (Test-Path $env:BACKUP_DIR)) { New-Item -ItemType Directory -Path $env:BACKUP_DIR -Force | Out-Null }

# Set global variables for script use
$global:RESET_ROOT = $env:RESET_ROOT
$global:LOG_DIR = $env:LOG_DIR
$global:BACKUP_DIR = $env:BACKUP_DIR
$global:SILENT_MODE = $Silent.IsPresent
$global:VERIFY_BACKUP = $VerifyBackup.IsPresent

# Set log file with current date
$timestamp = Get-Date -Format "yyyy-MM-dd"
$global:LOG_FILE = Join-Path $env:LOG_DIR "reset-operations-$timestamp.log"
$global:LAST_BACKUP = ""

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Please right-click and select 'Run as administrator'" -ForegroundColor Red
    if (-not $global:SILENT_MODE) { Read-Host "Press Enter to exit" }
    exit 1
}

# Function to log messages with color coding
function Write-LogMessage {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("ERROR", "SUCCESS", "WARN", "INFO", "DEBUG")]
        [string]$Level,
        
        [Parameter(Mandatory)]
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $global:LOG_FILE -Value $logEntry -Encoding UTF8
    
    # Color coding for console output
    switch ($Level) {
        "ERROR" { Write-Host "[$Level] $Message" -ForegroundColor Red }
        "SUCCESS" { Write-Host "[$Level] $Message" -ForegroundColor Green }
        "WARN" { Write-Host "[$Level] $Message" -ForegroundColor Yellow }
        "INFO" { Write-Host "[$Level] $Message" -ForegroundColor Cyan }
        "DEBUG" { Write-Host "[$Level] $Message" -ForegroundColor Gray }
        default { Write-Host "[$Level] $Message" }
    }
}

# Function to show progress
function Show-Progress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Operation
    )
    
    $percent = [math]::Round(($Current / $Total) * 100)
    
    # Create progress bar (20 characters)
    $bars = [math]::Floor($percent / 5)
    $progressBar = "█" * $bars + "░" * (20 - $bars)
    
    Write-Host "[$percent%] [$progressBar] $Operation" -ForegroundColor Cyan
}

# Function to create backup
function New-Backup {
    param(
        [Parameter(Mandatory)]
        [string]$BackupName,
        
        [Parameter(Mandatory)]
        [string]$SourcePath
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupPath = Join-Path $global:BACKUP_DIR "$BackupName`_$timestamp"
    
    Write-LogMessage -Level "INFO" -Message "Creating backup: $BackupName"
    
    try {
        if (Test-Path $SourcePath) {
            if (Test-Path $SourcePath -PathType Container) {
                # Directory backup
                Copy-Item -Path $SourcePath -Destination $backupPath -Recurse -Force
            } else {
                # File backup
                if (-not (Test-Path $backupPath)) { New-Item -ItemType Directory -Path $backupPath -Force | Out-Null }
                Copy-Item -Path $SourcePath -Destination $backupPath -Force
            }
            
            Write-LogMessage -Level "SUCCESS" -Message "Backup created successfully: $backupPath"
            $global:LAST_BACKUP = $backupPath
            return $true
        } else {
            Write-LogMessage -Level "WARN" -Message "Source path does not exist: $SourcePath"
            return $false
        }
    } catch {
        Write-LogMessage -Level "ERROR" -Message "Failed to create backup: $BackupName - $($_.Exception.Message)"
        
        if (-not $global:SILENT_MODE) {
            Write-Host ""
            Write-Host "WARNING: Backup creation failed!" -ForegroundColor Yellow
            $continue = Read-Host "Continue without backup? (y/N)"
            if ($continue -ne "y" -and $continue -ne "Y") {
                Write-Host "Operation cancelled for safety." -ForegroundColor Yellow
                exit 1
            }
        } else {
            Write-Host "ERROR: Cannot continue in silent mode without backup capability" -ForegroundColor Red
            exit 1
        }
        return $false
    }
}

# Enhanced function to create registry backup with verification
function Backup-Registry {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryKey,
        
        [Parameter(Mandatory)]
        [string]$BackupName
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $regBackupFile = Join-Path $global:BACKUP_DIR "$BackupName`_$timestamp.reg"
    
    Write-LogMessage -Level "INFO" -Message "Backing up registry key: $RegistryKey"
    
    try {
        # Export registry key
        $result = Start-Process -FilePath "reg.exe" -ArgumentList "export", "`"$RegistryKey`"", "`"$regBackupFile`"", "/y" -WindowStyle Hidden -PassThru -Wait
        
        if ($result.ExitCode -eq 0) {
            # Verify backup file is valid
            $content = Get-Content $regBackupFile -First 1 -ErrorAction SilentlyContinue
            if ($content -match "Windows Registry Editor") {
                Write-LogMessage -Level "SUCCESS" -Message "Registry backup created and verified: $regBackupFile"
                $global:LAST_BACKUP = $regBackupFile
                return $true
            } else {
                Write-LogMessage -Level "ERROR" -Message "Registry backup file appears corrupted"
                Remove-Item $regBackupFile -Force -ErrorAction SilentlyContinue
                return $false
            }
        } else {
            Write-LogMessage -Level "ERROR" -Message "Failed to backup registry key: $RegistryKey"
            return $false
        }
    } catch {
        Write-LogMessage -Level "ERROR" -Message "Error backing up registry: $($_.Exception.Message)"
        return $false
    }
}

# Enhanced confirmation function with better safety
function Confirm-Action {
    param(
        [Parameter(Mandatory)]
        [string]$Action
    )
    
    if ($global:SILENT_MODE) { return $true }
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "                WARNING" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This operation will: $Action" -ForegroundColor White
    Write-Host ""
    Write-Host "IMPORTANT:" -ForegroundColor Red -NoNewline
    Write-Host " This action cannot be easily undone without backups." -ForegroundColor White
    Write-Host "Make sure you have:"
    Write-Host "  • Created a system restore point"
    Write-Host "  • Backed up important data"
    Write-Host "  • Closed all applications"
    Write-Host ""
    Write-Host "Backups will be created automatically before changes." -ForegroundColor Cyan
    Write-Host ""
    
    $confirm = Read-Host "Do you want to continue? (yes/NO)"
    if ($confirm -eq "yes") {
        Write-LogMessage -Level "INFO" -Message "User confirmed operation: $Action"
        return $true
    } elseif ($confirm -eq "y") {
        Write-Host ""
        Write-Host "Please type 'yes' (not just 'y') to confirm this operation." -ForegroundColor Yellow
        $confirm2 = Read-Host "Type 'yes' to continue"
        if ($confirm2 -eq "yes") {
            Write-LogMessage -Level "INFO" -Message "User confirmed operation: $Action"
            return $true
        }
    }
    
    Write-LogMessage -Level "INFO" -Message "Operation cancelled by user"
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    return $false
}

# Function to check Windows version
function Test-WindowsVersion {
    $version = [System.Environment]::OSVersion.Version
    if ($version.Major -eq 10) {
        Write-LogMessage -Level "INFO" -Message "Windows 10/11 detected"
        return $true
    } else {
        Write-LogMessage -Level "WARN" -Message "This script is designed for Windows 10/11. Current version: $($version.Major).$($version.Minor)"
        return $false
    }
}

# Function to restart required services
function Restart-WindowsService {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName
    )
    
    Write-LogMessage -Level "INFO" -Message "Restarting service: $ServiceName"
    
    try {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Service -Name $ServiceName -ErrorAction Stop
        Write-LogMessage -Level "SUCCESS" -Message "Service restarted: $ServiceName"
        return $true
    } catch {
        Write-LogMessage -Level "WARN" -Message "Failed to restart service: $ServiceName - $($_.Exception.Message)"
        return $false
    }
}

# Function to kill process safely
function Stop-ProcessSafely {
    param(
        [Parameter(Mandatory)]
        [string]$ProcessName
    )
    
    Write-LogMessage -Level "INFO" -Message "Stopping process: $ProcessName"
    
    try {
        $processes = Get-Process -Name $ProcessName.Replace(".exe", "") -ErrorAction SilentlyContinue
        if ($processes) {
            $processes | Stop-Process -Force
            Write-LogMessage -Level "SUCCESS" -Message "Process stopped: $ProcessName"
            return $true
        } else {
            Write-LogMessage -Level "INFO" -Message "Process not running or already stopped: $ProcessName"
            return $true
        }
    } catch {
        Write-LogMessage -Level "WARN" -Message "Error stopping process: $ProcessName - $($_.Exception.Message)"
        return $false
    }
}

# Function to clear specific folder
function Clear-Folder {
    param(
        [Parameter(Mandatory)]
        [string]$FolderPath,
        
        [Parameter(Mandatory)]
        [string]$FolderName
    )
    
    if (Test-Path $FolderPath) {
        Write-LogMessage -Level "INFO" -Message "Clearing folder: $FolderName"
        
        try {
            Get-ChildItem -Path $FolderPath -Recurse -Force | Remove-Item -Recurse -Force
            Write-LogMessage -Level "SUCCESS" -Message "Folder cleared: $FolderName"
            return $true
        } catch {
            Write-LogMessage -Level "WARN" -Message "Some files could not be deleted in: $FolderName - $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-LogMessage -Level "INFO" -Message "Folder does not exist: $FolderName"
        return $true
    }
}

# Function to set registry value safely
function Set-RegistryValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        $Value,
        
        [Parameter(Mandatory)]
        [string]$Type
    )
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        return $true
    } catch {
        Write-LogMessage -Level "ERROR" -Message "Failed to set registry value: $Path\$Name - $($_.Exception.Message)"
        return $false
    }
}

# Function to remove registry value safely
function Remove-RegistryValue {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        
        [Parameter(Mandatory)]
        [string]$Name
    )
    
    try {
        if (Test-Path $Path) {
            Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
        }
        return $true
    } catch {
        Write-LogMessage -Level "ERROR" -Message "Failed to remove registry value: $Path\$Name - $($_.Exception.Message)"
        return $false
    }
}

# Export functions for use by other scripts
Export-ModuleMember -Function @(
    'Write-LogMessage',
    'Show-Progress', 
    'New-Backup',
    'Backup-Registry',
    'Confirm-Action',
    'Test-WindowsVersion',
    'Restart-WindowsService',
    'Stop-ProcessSafely',
    'Clear-Folder',
    'Set-RegistryValue',
    'Remove-RegistryValue'
)

# Set global variables for backward compatibility
$global:LOG_FILE = $global:LOG_FILE
$global:LAST_BACKUP = $global:LAST_BACKUP
$global:SILENT_MODE = $global:SILENT_MODE
$global:VERIFY_BACKUP = $global:VERIFY_BACKUP

Write-LogMessage -Level "INFO" -Message "Utils module loaded successfully"