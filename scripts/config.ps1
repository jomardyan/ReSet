# Windows Settings Reset Toolkit - Configuration Manager
# Handles reading and writing configuration settings

param(
    [ValidateSet("read", "write", "show", "validate", "get", "set")]
    [string]$Operation,
    
    [string]$Key,
    [string]$Value,
    [string]$ConfigFilePath
)

# Import utils module
$utilsPath = Join-Path $PSScriptRoot "utils.ps1"
if (Test-Path $utilsPath) {
    Import-Module $utilsPath -Force
}

# Set default config file location
if (-not $ConfigFilePath) {
    $ConfigFilePath = Join-Path (Split-Path $PSScriptRoot -Parent) "config.ini"
}

# Initialize default configuration values
$global:Config = @{
    LogLevel = "INFO"
    LogRetentionDays = 30
    BackupRetentionDays = 30
    CreateBackups = $true
    CreateRestorePoint = $true
    RequireConfirmation = $true
    SilentMode = $false
    VerifyBackups = $true
    SafeModeEnabled = $true
    ParallelExecution = $false
    MaxConcurrentOperations = 3
    DelayBetweenOperations = 2
    LogDirectory = "logs"
    BackupDirectory = "backups"
    ScriptsDirectory = "scripts"
}

# Function to read configuration from file
function Read-Configuration {
    param([string]$FilePath = $ConfigFilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "[WARN] Configuration file not found: $FilePath" -ForegroundColor Yellow
        Write-Host "[INFO] Using default configuration values" -ForegroundColor Cyan
        return
    }
    
    Write-Host "[INFO] Loading configuration from: $FilePath" -ForegroundColor Cyan
    
    try {
        $content = Get-Content $FilePath -Encoding UTF8
        
        foreach ($line in $content) {
            # Skip comments and empty lines
            if ($line -match '^\s*#' -or $line -match '^\s*$' -or $line -match '^\s*\[') {
                continue
            }
            
            # Parse key=value pairs
            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Convert string values to appropriate types
                switch ($key) {
                    "LogRetentionDays" { $global:Config[$key] = [int]$value }
                    "BackupRetentionDays" { $global:Config[$key] = [int]$value }
                    "MaxConcurrentOperations" { $global:Config[$key] = [int]$value }
                    "DelayBetweenOperations" { $global:Config[$key] = [int]$value }
                    "CreateBackups" { $global:Config[$key] = $value -eq "true" }
                    "CreateRestorePoint" { $global:Config[$key] = $value -eq "true" }
                    "RequireConfirmation" { $global:Config[$key] = $value -eq "true" }
                    "SilentMode" { $global:Config[$key] = $value -eq "true" }
                    "VerifyBackups" { $global:Config[$key] = $value -eq "true" }
                    "SafeModeEnabled" { $global:Config[$key] = $value -eq "true" }
                    "ParallelExecution" { $global:Config[$key] = $value -eq "true" }
                    default { $global:Config[$key] = $value }
                }
            }
        }
        
        Write-Host "[INFO] Configuration loaded successfully" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to read configuration: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to write configuration to file
function Write-Configuration {
    param([string]$FilePath = $ConfigFilePath)
    
    Write-Host "[INFO] Writing configuration to: $FilePath" -ForegroundColor Cyan
    
    try {
        $content = @()
        $content += "# ReSet Toolkit Configuration File"
        $content += "# Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $content += ""
        $content += "[Settings]"
        $content += "LogLevel=$($global:Config.LogLevel)"
        $content += "LogRetentionDays=$($global:Config.LogRetentionDays)"
        $content += "BackupRetentionDays=$($global:Config.BackupRetentionDays)"
        $content += "CreateBackups=$($global:Config.CreateBackups.ToString().ToLower())"
        $content += "CreateRestorePoint=$($global:Config.CreateRestorePoint.ToString().ToLower())"
        $content += "RequireConfirmation=$($global:Config.RequireConfirmation.ToString().ToLower())"
        $content += "SilentMode=$($global:Config.SilentMode.ToString().ToLower())"
        $content += "VerifyBackups=$($global:Config.VerifyBackups.ToString().ToLower())"
        $content += "SafeModeEnabled=$($global:Config.SafeModeEnabled.ToString().ToLower())"
        $content += "ParallelExecution=$($global:Config.ParallelExecution.ToString().ToLower())"
        $content += "MaxConcurrentOperations=$($global:Config.MaxConcurrentOperations)"
        $content += "DelayBetweenOperations=$($global:Config.DelayBetweenOperations)"
        $content += ""
        $content += "[Paths]"
        $content += "LogDirectory=$($global:Config.LogDirectory)"
        $content += "BackupDirectory=$($global:Config.BackupDirectory)"
        $content += "ScriptsDirectory=$($global:Config.ScriptsDirectory)"
        
        $content | Out-File -FilePath $FilePath -Encoding UTF8 -Force
        Write-Host "[INFO] Configuration saved successfully" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Failed to write configuration: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to get configuration value
function Get-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [string]$DefaultValue = ""
    )
    
    if ($global:Config.ContainsKey($Key)) {
        return $global:Config[$Key]
    } else {
        return $DefaultValue
    }
}

# Function to set configuration value
function Set-ConfigValue {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [string]$Value
    )
    
    # Convert string values to appropriate types based on key
    switch ($Key) {
        "LogRetentionDays" { $global:Config[$Key] = [int]$Value }
        "BackupRetentionDays" { $global:Config[$Key] = [int]$Value }
        "MaxConcurrentOperations" { $global:Config[$Key] = [int]$Value }
        "DelayBetweenOperations" { $global:Config[$Key] = [int]$Value }
        {$_ -in @("CreateBackups", "CreateRestorePoint", "RequireConfirmation", "SilentMode", "VerifyBackups", "SafeModeEnabled", "ParallelExecution")} {
            $global:Config[$Key] = $Value -eq "true"
        }
        default { $global:Config[$Key] = $Value }
    }
}

# Function to validate configuration
function Test-Configuration {
    $validationErrors = 0
    
    # Validate numeric values
    if ($global:Config.LogRetentionDays -lt 1) {
        Write-Host "[ERROR] LogRetentionDays must be greater than 0" -ForegroundColor Red
        $validationErrors++
    }
    
    if ($global:Config.BackupRetentionDays -lt 1) {
        Write-Host "[ERROR] BackupRetentionDays must be greater than 0" -ForegroundColor Red
        $validationErrors++
    }
    
    if ($global:Config.MaxConcurrentOperations -lt 1) {
        Write-Host "[ERROR] MaxConcurrentOperations must be greater than 0" -ForegroundColor Red
        $validationErrors++
    }
    
    # Validate paths exist or can be created
    $basePath = Split-Path $ConfigFilePath -Parent
    
    foreach ($pathKey in @("LogDirectory", "BackupDirectory", "ScriptsDirectory")) {
        $path = Join-Path $basePath $global:Config[$pathKey]
        if (-not (Test-Path $path)) {
            try {
                New-Item -ItemType Directory -Path $path -Force | Out-Null
            } catch {
                Write-Host "[ERROR] Cannot create directory for $pathKey`: $path" -ForegroundColor Red
                $validationErrors++
            }
        }
    }
    
    if ($validationErrors -gt 0) {
        Write-Host "[ERROR] Configuration validation failed with $validationErrors errors" -ForegroundColor Red
        return $false
    } else {
        Write-Host "[INFO] Configuration validation passed" -ForegroundColor Green
        return $true
    }
}

# Function to show current configuration
function Show-Configuration {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  ReSet Toolkit Configuration" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[Settings]" -ForegroundColor Yellow
    Write-Host "LogLevel: $($global:Config.LogLevel)"
    Write-Host "LogRetentionDays: $($global:Config.LogRetentionDays)"
    Write-Host "BackupRetentionDays: $($global:Config.BackupRetentionDays)"
    Write-Host "CreateBackups: $($global:Config.CreateBackups)"
    Write-Host "CreateRestorePoint: $($global:Config.CreateRestorePoint)"
    Write-Host "RequireConfirmation: $($global:Config.RequireConfirmation)"
    Write-Host "SilentMode: $($global:Config.SilentMode)"
    Write-Host "SafeModeEnabled: $($global:Config.SafeModeEnabled)"
    Write-Host ""
    Write-Host "[Paths]" -ForegroundColor Yellow
    Write-Host "LogDirectory: $($global:Config.LogDirectory)"
    Write-Host "BackupDirectory: $($global:Config.BackupDirectory)"
    Write-Host "ScriptsDirectory: $($global:Config.ScriptsDirectory)"
    Write-Host ""
    Write-Host "Configuration file: $ConfigFilePath" -ForegroundColor Gray
    Write-Host ""
}

# Main execution based on operation parameter
switch ($Operation) {
    "read" { Read-Configuration }
    "write" { Write-Configuration }
    "show" { Show-Configuration }
    "validate" { Test-Configuration }
    "get" { 
        if ($Key) { 
            $result = Get-ConfigValue -Key $Key -DefaultValue $Value
            Write-Output $result
        } else {
            Write-Host "[ERROR] Key parameter required for get operation" -ForegroundColor Red
        }
    }
    "set" { 
        if ($Key -and $Value) {
            Set-ConfigValue -Key $Key -Value $Value
        } else {
            Write-Host "[ERROR] Both Key and Value parameters required for set operation" -ForegroundColor Red
        }
    }
    default {
        Write-Host "Usage: config.ps1 -Operation [read|write|show|validate|get|set] [-Key <key>] [-Value <value>]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Cyan
        Write-Host "  read       - Load configuration from file"
        Write-Host "  write      - Save current configuration to file"
        Write-Host "  show       - Display current configuration"
        Write-Host "  validate   - Validate configuration values"
        Write-Host "  get        - Get configuration value (requires -Key)"
        Write-Host "  set        - Set configuration value (requires -Key and -Value)"
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Gray
        Write-Host "  config.ps1 -Operation read"
        Write-Host "  config.ps1 -Operation get -Key LogLevel"
        Write-Host "  config.ps1 -Operation set -Key SilentMode -Value true"
    }
}

# Export configuration hashtable for use by other scripts
Export-ModuleMember -Variable Config