# Windows Settings Reset Toolkit - PowerShell Validation System
# Tests all reset scripts and validates the installation with comprehensive analysis

[CmdletBinding()]
param(
    [switch]$Silent,
    [switch]$Detailed,
    [switch]$SkipPerformanceTests,
    [string]$LogPath = $null,
    [ValidateSet('Basic', 'Standard', 'Comprehensive')]
    [string]$ValidationLevel = 'Standard'
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
$Script:TestsPassed = 0
$Script:TestsFailed = 0
$Script:TestsSkipped = 0
$Script:CriticalErrors = 0
$Script:LogFile = $null

# Console colors for professional output
$Colors = @{
    Header = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; 
    Error = 'Red'; Info = 'White'; Muted = 'DarkGray'; Emphasis = 'Magenta'
}

function Write-ValidationLog {
    param(
        [ValidateSet('INFO', 'PASS', 'FAIL', 'SKIP', 'CRITICAL', 'DEBUG')]
        [string]$Level,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output with colors and symbols
    $color = switch ($Level) {
        'PASS' { $Colors.Success }
        'FAIL' { $Colors.Error }
        'SKIP' { $Colors.Warning }
        'CRITICAL' { $Colors.Error }
        'DEBUG' { $Colors.Muted }
        default { $Colors.Info }
    }
    
    $symbol = switch ($Level) {
        'PASS' { '✓' }
        'FAIL' { '✗' }
        'SKIP' { '~' }
        'CRITICAL' { '!' }
        'DEBUG' { '•' }
        default { 'i' }
    }
    
    if (-not $Silent) {
        Write-Host "[$symbol] $Message" -ForegroundColor $color
    }
    
    # Update counters
    switch ($Level) {
        'PASS' { $Script:TestsPassed++ }
        'FAIL' { $Script:TestsFailed++ }
        'SKIP' { $Script:TestsSkipped++ }
        'CRITICAL' { $Script:CriticalErrors++ }
    }
    
    # File output
    if ($Script:LogFile) {
        $logEntry | Out-File -FilePath $Script:LogFile -Append -Encoding UTF8
    }
}

function Initialize-ValidationLogging {
    $rootDir = Split-Path $PSScriptRoot -Parent
    $logsDir = Join-Path $rootDir "logs"
    
    if (-not (Test-Path $logsDir)) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }
    
    $logFileName = "validation-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').log"
    $Script:LogFile = if ($LogPath) { $LogPath } else { Join-Path $logsDir $logFileName }
    
    try {
        $logHeader = @"
===============================================
ReSet Toolkit PowerShell Validation System Log
===============================================
Validation Date: $(Get-Date)
Computer: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
OS Version: $([System.Environment]::OSVersion.VersionString)
Validation Level: $ValidationLevel
Parameters: Silent=$Silent, Detailed=$Detailed, SkipPerformanceTests=$SkipPerformanceTests
===============================================

"@
        $logHeader | Out-File -FilePath $Script:LogFile -Encoding UTF8
        Write-ValidationLog -Level 'INFO' -Message "Validation system initialized"
    } catch {
        Write-Warning "Could not initialize validation logging: $($_.Exception.Message)"
    }
}

function Test-AdministratorPrivileges {
    Write-ValidationLog -Level 'INFO' -Message "Testing administrator privileges..."
    
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
            Write-ValidationLog -Level 'PASS' -Message "Administrator privileges confirmed"
            return $true
        } else {
            Write-ValidationLog -Level 'CRITICAL' -Message "Administrator privileges required but not detected"
            return $false
        }
    } catch {
        Write-ValidationLog -Level 'CRITICAL' -Message "Could not determine administrator status: $($_.Exception.Message)"
        return $false
    }
}

function Test-DirectoryStructure {
    Write-ValidationLog -Level 'INFO' -Message "Validating directory structure..."
    
    $rootDir = Split-Path $PSScriptRoot -Parent
    $requiredDirs = @('scripts', 'logs', 'backups', 'gui', 'cli', 'modules', 'config')
    $allValid = $true
    
    foreach ($dir in $requiredDirs) {
        $dirPath = Join-Path $rootDir $dir
        if (Test-Path $dirPath) {
            Write-ValidationLog -Level 'PASS' -Message "Directory exists: $dir"
        } else {
            Write-ValidationLog -Level 'FAIL' -Message "Missing directory: $dir"
            $allValid = $false
        }
    }
    
    return $allValid
}

function Test-CoreFiles {
    Write-ValidationLog -Level 'INFO' -Message "Checking core files..."
    
    $rootDir = Split-Path $PSScriptRoot -Parent
    $coreFiles = @{
        'Install-ReSet.ps1' = 'Installation script'
        'Start-ReSetGUI.ps1' = 'GUI launcher'
        'Clear-ReSetData.ps1' = 'Cleanup script'
        'Restore-ReSetBackup.ps1' = 'Backup restore utility'
        'modules\ReSetUtils.psm1' = 'Utilities module'
        'config.ini' = 'Configuration file'
    }
    
    $allValid = $true
    
    foreach ($file in $coreFiles.Keys) {
        $filePath = Join-Path $rootDir $file
        $description = $coreFiles[$file]
        
        if (Test-Path $filePath) {
            Write-ValidationLog -Level 'PASS' -Message "Core file exists: $file ($description)"
        } else {
            Write-ValidationLog -Level 'CRITICAL' -Message "Missing core file: $file ($description)"
            $allValid = $false
        }
    }
    
    return $allValid
}

function Test-PowerShellScripts {
    Write-ValidationLog -Level 'INFO' -Message "Validating PowerShell reset scripts..."
    
    $scriptsDir = Join-Path (Split-Path $PSScriptRoot -Parent) "scripts"
    $scriptCount = 0
    $validScripts = 0
    
    if (Test-Path $scriptsDir) {
        $resetScripts = Get-ChildItem -Path $scriptsDir -Filter "Reset-*.ps1" -ErrorAction SilentlyContinue
        
        foreach ($script in $resetScripts) {
            $scriptCount++
            $scriptName = $script.Name
            $scriptPath = $script.FullName
            $isValid = $true
            
            try {
                # Check script header
                $content = Get-Content -Path $scriptPath -TotalCount 10
                if ($content -match "Windows Settings Reset Toolkit|ReSet Toolkit") {
                    Write-ValidationLog -Level 'PASS' -Message "Script header valid: $scriptName"
                } else {
                    Write-ValidationLog -Level 'FAIL' -Message "Invalid script header: $scriptName"
                    $isValid = $false
                }
                
                # Check for parameter block
                if ($content -match "\[CmdletBinding\(\)\]|\[Parameter\(") {
                    Write-ValidationLog -Level 'PASS' -Message "Parameter block found: $scriptName"
                } else {
                    Write-ValidationLog -Level 'FAIL' -Message "Missing parameter block: $scriptName"
                    $isValid = $false
                }
                
                # Check for error handling
                $fullContent = Get-Content -Path $scriptPath
                if ($fullContent -match "try\s*{|catch\s*{|\$ErrorActionPreference") {
                    Write-ValidationLog -Level 'PASS' -Message "Error handling found: $scriptName"
                } else {
                    Write-ValidationLog -Level 'FAIL' -Message "Missing error handling: $scriptName"
                    $isValid = $false
                }
                
                # Check for logging functionality
                if ($fullContent -match "Write-.*Log|Out-File.*log") {
                    Write-ValidationLog -Level 'PASS' -Message "Logging functionality found: $scriptName"
                } else {
                    Write-ValidationLog -Level 'FAIL' -Message "Missing logging functionality: $scriptName"
                    $isValid = $false
                }
                
                if ($isValid) {
                    $validScripts++
                }
                
            } catch {
                Write-ValidationLog -Level 'FAIL' -Message "Error reading script $scriptName : $($_.Exception.Message)"
            }
        }
    }
    
    Write-ValidationLog -Level 'INFO' -Message "Found $scriptCount PowerShell reset scripts"
    
    if ($scriptCount -ge 20) {
        Write-ValidationLog -Level 'PASS' -Message "Expected number of reset scripts found ($scriptCount/20+)"
    } else {
        Write-ValidationLog -Level 'FAIL' -Message "Missing reset scripts (found $scriptCount, expected 20+)"
    }
    
    return ($validScripts -eq $scriptCount -and $scriptCount -ge 20)
}

function Test-PowerShellCompatibility {
    Write-ValidationLog -Level 'INFO' -Message "Testing PowerShell compatibility..."
    
    $psVersion = $PSVersionTable.PSVersion
    Write-ValidationLog -Level 'DEBUG' -Message "PowerShell Version: $psVersion"
    
    if ($psVersion.Major -ge 7) {
        Write-ValidationLog -Level 'PASS' -Message "PowerShell 7+ detected - Excellent compatibility"
    } elseif ($psVersion.Major -ge 5) {
        Write-ValidationLog -Level 'PASS' -Message "PowerShell 5.x detected - Good compatibility"
    } else {
        Write-ValidationLog -Level 'FAIL' -Message "PowerShell version too old: $psVersion"
        return $false
    }
    
    # Test .NET Framework availability
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        Write-ValidationLog -Level 'PASS' -Message ".NET Windows Forms available"
    } catch {
        Write-ValidationLog -Level 'FAIL' -Message ".NET Windows Forms not available"
        return $false
    }
    
    return $true
}

function Test-SystemCompatibility {
    Write-ValidationLog -Level 'INFO' -Message "Checking system compatibility..."
    
    $osVersion = [System.Environment]::OSVersion.Version
    $osName = (Get-WmiObject Win32_OperatingSystem).Caption
    
    Write-ValidationLog -Level 'DEBUG' -Message "Operating System: $osName ($($osVersion.Major).$($osVersion.Minor))"
    
    if ($osVersion.Major -eq 10) {
        Write-ValidationLog -Level 'PASS' -Message "Windows 10/11 detected (fully compatible)"
        return $true
    } elseif ($osVersion.Major -eq 6 -and $osVersion.Minor -ge 1) {
        Write-ValidationLog -Level 'PASS' -Message "Windows 7/8 detected (limited compatibility)"
        return $true
    } else {
        Write-ValidationLog -Level 'FAIL' -Message "Unsupported Windows version: $($osVersion.Major).$($osVersion.Minor)"
        return $false
    }
}

function Test-DiskSpace {
    Write-ValidationLog -Level 'INFO' -Message "Checking available disk space..."
    
    try {
        $drive = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($drive.Size / 1GB, 2)
        $usagePercent = [math]::Round((($totalSpaceGB - $freeSpaceGB) / $totalSpaceGB) * 100, 1)
        
        Write-ValidationLog -Level 'DEBUG' -Message "Disk space: $freeSpaceGB GB free of $totalSpaceGB GB ($usagePercent% used)"
        
        if ($freeSpaceGB -lt 1) {
            Write-ValidationLog -Level 'FAIL' -Message "Critical: Very low disk space ($freeSpaceGB GB free)"
            return $false
        } elseif ($freeSpaceGB -lt 5) {
            Write-ValidationLog -Level 'FAIL' -Message "Low disk space detected ($freeSpaceGB GB free)"
            return $false
        } else {
            Write-ValidationLog -Level 'PASS' -Message "Sufficient disk space available ($freeSpaceGB GB free)"
            return $true
        }
    } catch {
        Write-ValidationLog -Level 'SKIP' -Message "Could not determine disk space: $($_.Exception.Message)"
        return $true
    }
}

function Test-RegistryAccess {
    Write-ValidationLog -Level 'INFO' -Message "Testing registry access..."
    
    try {
        $testKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion"
        $result = Get-ItemProperty -Path $testKey -ErrorAction Stop
        Write-ValidationLog -Level 'PASS' -Message "Registry access working correctly"
        return $true
    } catch {
        Write-ValidationLog -Level 'CRITICAL' -Message "Registry access failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-ServiceAccess {
    Write-ValidationLog -Level 'INFO' -Message "Testing Windows service access..."
    
    try {
        $services = Get-Service -Name "Themes", "AudioSrv", "BITS" -ErrorAction SilentlyContinue
        if ($services.Count -ge 3) {
            Write-ValidationLog -Level 'PASS' -Message "Windows service access working"
            return $true
        } else {
            Write-ValidationLog -Level 'FAIL' -Message "Limited Windows service access"
            return $false
        }
    } catch {
        Write-ValidationLog -Level 'FAIL' -Message "Windows service access failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-NetworkConnectivity {
    if ($SkipPerformanceTests) {
        Write-ValidationLog -Level 'SKIP' -Message "Network test skipped (performance tests disabled)"
        return $true
    }
    
    Write-ValidationLog -Level 'INFO' -Message "Testing network connectivity..."
    
    try {
        $result = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -ErrorAction SilentlyContinue
        if ($result) {
            Write-ValidationLog -Level 'PASS' -Message "Network connectivity working"
            return $true
        } else {
            Write-ValidationLog -Level 'FAIL' -Message "Network connectivity issues detected"
            return $false
        }
    } catch {
        # Fallback to ping
        try {
            $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
            if ($ping) {
                Write-ValidationLog -Level 'PASS' -Message "Network connectivity working (ping test)"
                return $true
            } else {
                Write-ValidationLog -Level 'FAIL' -Message "Network connectivity issues (ping failed)"
                return $false
            }
        } catch {
            Write-ValidationLog -Level 'SKIP' -Message "Could not test network connectivity"
            return $true
        }
    }
}

function Test-ConfigurationSystem {
    Write-ValidationLog -Level 'INFO' -Message "Testing configuration system..."
    
    $rootDir = Split-Path $PSScriptRoot -Parent
    $configFile = Join-Path $rootDir "config.ini"
    
    if (Test-Path $configFile) {
        try {
            $configContent = Get-Content $configFile
            if ($configContent -match "\[.*\]" -and $configContent -match ".*=.*") {
                Write-ValidationLog -Level 'PASS' -Message "Configuration file format valid"
                return $true
            } else {
                Write-ValidationLog -Level 'FAIL' -Message "Configuration file format invalid"
                return $false
            }
        } catch {
            Write-ValidationLog -Level 'FAIL' -Message "Configuration file read error: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-ValidationLog -Level 'FAIL' -Message "Configuration file missing"
        return $false
    }
}

function Test-ModuleSystem {
    Write-ValidationLog -Level 'INFO' -Message "Testing PowerShell module system..."
    
    $moduleDir = Join-Path (Split-Path $PSScriptRoot -Parent) "modules"
    $utilsModule = Join-Path $moduleDir "ReSetUtils.psm1"
    
    if (Test-Path $utilsModule) {
        try {
            Import-Module $utilsModule -Force -ErrorAction Stop
            Write-ValidationLog -Level 'PASS' -Message "PowerShell utilities module loads successfully"
            return $true
        } catch {
            Write-ValidationLog -Level 'FAIL' -Message "PowerShell utilities module has errors: $($_.Exception.Message)"
            return $false
        }
    } else {
        Write-ValidationLog -Level 'FAIL' -Message "PowerShell utilities module missing"
        return $false
    }
}

function Invoke-ValidationByLevel {
    param([string]$Level)
    
    $testResults = @()
    
    # Basic tests (all levels)
    $testResults += Test-AdministratorPrivileges
    $testResults += Test-DirectoryStructure
    $testResults += Test-CoreFiles
    $testResults += Test-PowerShellCompatibility
    $testResults += Test-SystemCompatibility
    
    # Standard tests
    if ($Level -in @('Standard', 'Comprehensive')) {
        $testResults += Test-PowerShellScripts
        $testResults += Test-DiskSpace
        $testResults += Test-RegistryAccess
        $testResults += Test-ConfigurationSystem
    }
    
    # Comprehensive tests
    if ($Level -eq 'Comprehensive') {
        $testResults += Test-ServiceAccess
        $testResults += Test-NetworkConnectivity
        $testResults += Test-ModuleSystem
    }
    
    return $testResults
}

function Show-ValidationSummary {
    $totalTests = $Script:TestsPassed + $Script:TestsFailed + $Script:TestsSkipped
    $passPercentage = if ($totalTests -gt 0) { [math]::Round(($Script:TestsPassed / $totalTests) * 100, 1) } else { 0 }
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor $Colors.Header
        Write-Host " Validation Results Summary" -ForegroundColor $Colors.Header
        Write-Host "============================================" -ForegroundColor $Colors.Header
        Write-Host ""
        Write-Host "Tests Passed: $($Script:TestsPassed)" -ForegroundColor $Colors.Success
        Write-Host "Tests Failed: $($Script:TestsFailed)" -ForegroundColor $(if ($Script:TestsFailed -gt 0) { $Colors.Error } else { $Colors.Success })
        Write-Host "Tests Skipped: $($Script:TestsSkipped)" -ForegroundColor $Colors.Warning
        Write-Host "Critical Errors: $($Script:CriticalErrors)" -ForegroundColor $(if ($Script:CriticalErrors -gt 0) { $Colors.Error } else { $Colors.Success })
        Write-Host "Total Tests: $totalTests" -ForegroundColor $Colors.Info
        Write-Host ""
        Write-Host "Pass Rate: $passPercentage%" -ForegroundColor $(if ($passPercentage -ge 90) { $Colors.Success } elseif ($passPercentage -ge 70) { $Colors.Warning } else { $Colors.Error })
        Write-Host ""
    }
    
    # Determine overall status
    if ($Script:CriticalErrors -gt 0) {
        $status = "CRITICAL ISSUES DETECTED"
        $statusColor = $Colors.Error
        $message = "The toolkit has critical issues that must be resolved before use."
        $exitCode = 2
    } elseif ($Script:TestsFailed -gt 0) {
        $status = "VALIDATION FAILED" 
        $statusColor = $Colors.Warning
        $message = "Some tests failed. Review the issues before using the toolkit."
        $exitCode = 1
    } else {
        $status = "VALIDATION PASSED"
        $statusColor = $Colors.Success
        $message = "The ReSet Toolkit is ready for use."
        $exitCode = 0
    }
    
    if (-not $Silent) {
        Write-Host "Status: $status" -ForegroundColor $statusColor
        Write-Host $message -ForegroundColor $Colors.Info
        Write-Host ""
        
        if ($Script:LogFile) {
            Write-Host "Validation log saved to: $(Split-Path $Script:LogFile -Leaf)" -ForegroundColor $Colors.Muted
        }
    }
    
    Write-ValidationLog -Level 'INFO' -Message "Validation completed: $($Script:TestsPassed) passed, $($Script:TestsFailed) failed, $($Script:TestsSkipped) skipped"
    Write-ValidationLog -Level 'INFO' -Message "Final status: $status"
    
    return $exitCode
}

# Main execution
try {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host " ReSet Toolkit PowerShell Validation System" -ForegroundColor $Colors.Header
    Write-Host "============================================" -ForegroundColor $Colors.Header
    Write-Host ""
    
    Initialize-ValidationLogging
    
    if (-not $Silent) {
        Write-Host "Validation Level: $ValidationLevel" -ForegroundColor $Colors.Emphasis
        Write-Host "Performance Tests: $(if ($SkipPerformanceTests) { 'Disabled' } else { 'Enabled' })" -ForegroundColor $Colors.Info
        Write-Host ""
    }
    
    Write-ValidationLog -Level 'INFO' -Message "Starting ReSet Toolkit validation (Level: $ValidationLevel)"
    
    $testResults = Invoke-ValidationByLevel -Level $ValidationLevel
    $exitCode = Show-ValidationSummary
    
    if (-not $Silent) {
        Write-Host ""
        Read-Host "Press Enter to continue"
    }
    
    exit $exitCode
    
} catch {
    Write-ValidationLog -Level 'CRITICAL' -Message "Validation system failed: $($_.Exception.Message)"
    
    if ($_.Exception.InnerException) {
        Write-ValidationLog -Level 'CRITICAL' -Message "Inner exception: $($_.Exception.InnerException.Message)"
    }
    
    if (-not $Silent) {
        Write-Host ""
        Write-Host "Validation system failed: $($_.Exception.Message)" -ForegroundColor $Colors.Error
        Read-Host "Press Enter to continue"
    }
    
    exit 3
}