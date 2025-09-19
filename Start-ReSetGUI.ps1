# ReSet Toolkit - PowerShell GUI Launcher
# Enhanced launcher for the ReSet Toolkit GUI application with comprehensive error handling

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$Silent,
    [switch]$NoElevation,
    [string]$GuiPath = $null
)

#Requires -Version 5.0

# Enhanced error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Console colors for professional output
$Colors = @{
    Header = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; 
    Error = 'Red'; Info = 'White'; Muted = 'DarkGray'
}

function Write-LauncherHeader {
    if ($Silent) { return }
    
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor $Colors.Header
    Write-Host "  ReSet Toolkit - PowerShell GUI Launcher v2.1" -ForegroundColor $Colors.Header
    Write-Host "=================================================" -ForegroundColor $Colors.Header
    Write-Host ""
}

function Write-LauncherSuccess {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "✓ $Message" -ForegroundColor $Colors.Success
    }
}

function Write-LauncherWarning {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "⚠ $Message" -ForegroundColor $Colors.Warning
    }
}

function Write-LauncherError {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Colors.Error
}

function Write-LauncherInfo {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "• $Message" -ForegroundColor $Colors.Info
    }
}

function Test-AdministratorPrivileges {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        Write-LauncherWarning "Could not determine administrator status: $($_.Exception.Message)"
        return $false
    }
}

function Request-Elevation {
    param([string]$ScriptPath)
    
    if ($NoElevation) {
        Write-LauncherWarning "Elevation disabled by parameter. Some features may not work correctly."
        return $false
    }
    
    if (-not $Silent) {
        Write-LauncherInfo "Requesting administrator privileges..."
        Write-LauncherWarning "A User Account Control (UAC) prompt will appear."
    }
    
    try {
        $arguments = @(
            '-ExecutionPolicy', 'Bypass'
            '-WindowStyle', 'Hidden'
            '-File', "`"$ScriptPath`""
        )
        
        if ($Silent) {
            $arguments += '-Silent'
        }
        
        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -Verb RunAs -PassThru
        
        if ($process) {
            Write-LauncherSuccess "Successfully elevated privileges"
            return $true
        } else {
            Write-LauncherError "Failed to start elevated process"
            return $false
        }
    } catch [System.ComponentModel.Win32Exception] {
        if ($_.Exception.NativeErrorCode -eq 1223) {
            Write-LauncherWarning "User cancelled elevation request"
        } else {
            Write-LauncherError "Elevation failed: $($_.Exception.Message)"
        }
        return $false
    } catch {
        Write-LauncherError "Unexpected error during elevation: $($_.Exception.Message)"
        return $false
    }
}

function Test-PowerShellVersion {
    $psVersion = $PSVersionTable.PSVersion
    Write-LauncherInfo "PowerShell Version: $psVersion"
    
    if ($psVersion.Major -ge 7) {
        Write-LauncherSuccess "PowerShell 7+ detected - Full feature support"
        return 'Excellent'
    } elseif ($psVersion.Major -ge 5) {
        Write-LauncherSuccess "PowerShell 5.x detected - Good compatibility"
        return 'Good'
    } else {
        Write-LauncherWarning "PowerShell version $psVersion may have limited compatibility"
        if (-not $Force) {
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -notmatch '^(y|yes)$') {
                return 'Cancelled'
            }
        }
        return 'Limited'
    }
}

function Find-GuiScript {
    # Priority order for finding GUI script
    $searchPaths = @()
    
    # 1. Explicit parameter
    if ($GuiPath -and (Test-Path $GuiPath)) {
        return $GuiPath
    }
    
    # 2. Relative to script directory
    $scriptDir = $PSScriptRoot
    $searchPaths += Join-Path $scriptDir "gui\ReSetGUI.ps1"
    
    # 3. Current directory
    $searchPaths += ".\gui\ReSetGUI.ps1"
    $searchPaths += ".\ReSetGUI.ps1"
    
    # 4. Environment variable
    $toolkitHome = $env:RESET_TOOLKIT_HOME
    if ($toolkitHome) {
        $searchPaths += Join-Path $toolkitHome "gui\ReSetGUI.ps1"
        $searchPaths += Join-Path $toolkitHome "ReSetGUI.ps1"
    }
    
    # 5. Common installation paths
    $searchPaths += "C:\ReSet\gui\ReSetGUI.ps1"
    $searchPaths += "C:\Program Files\ReSet Toolkit\gui\ReSetGUI.ps1"
    
    Write-LauncherInfo "Searching for GUI script..."
    
    foreach ($path in $searchPaths) {
        Write-LauncherInfo "Checking: $path"
        if (Test-Path $path) {
            $fullPath = Resolve-Path $path
            Write-LauncherSuccess "Found GUI script: $fullPath"
            return $fullPath.Path
        }
    }
    
    return $null
}

function Test-GuiPrerequisites {
    param([string]$GuiScriptPath)
    
    Write-LauncherInfo "Validating GUI prerequisites..."
    
    # Check if script is readable
    try {
        $null = Get-Content -Path $GuiScriptPath -TotalCount 1
        Write-LauncherSuccess "GUI script is accessible"
    } catch {
        Write-LauncherError "Cannot read GUI script: $($_.Exception.Message)"
        return $false
    }
    
    # Check for .NET Framework (required for Windows Forms)
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        Write-LauncherSuccess ".NET Windows Forms available"
    } catch {
        Write-LauncherError ".NET Framework with Windows Forms support required"
        return $false
    }
    
    # Check execution policy
    $executionPolicy = Get-ExecutionPolicy -Scope Process
    if ($executionPolicy -eq 'Restricted') {
        Write-LauncherWarning "PowerShell execution policy is Restricted"
        Write-LauncherInfo "Launching with -ExecutionPolicy Bypass"
    } else {
        Write-LauncherSuccess "PowerShell execution policy: $executionPolicy"
    }
    
    return $true
}

function Start-GuiApplication {
    param([string]$GuiScriptPath)
    
    Write-LauncherInfo "Starting GUI application..."
    Write-LauncherInfo "Script: $(Split-Path $GuiScriptPath -Leaf)"
    
    $arguments = @(
        '-ExecutionPolicy', 'Bypass'
        '-WindowStyle', 'Hidden'
        '-File', "`"$GuiScriptPath`""
    )
    
    if ($Silent) {
        $arguments += '-Silent'
    }
    
    try {
        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru
        
        if ($process) {
            Write-LauncherSuccess "GUI application started successfully"
            Write-LauncherInfo "Process ID: $($process.Id)"
            
            # Wait a moment to check if it started properly
            Start-Sleep -Seconds 2
            
            if (-not $process.HasExited) {
                Write-LauncherSuccess "GUI application is running"
                return $true
            } else {
                Write-LauncherError "GUI application exited immediately (Exit Code: $($process.ExitCode))"
                return $false
            }
        } else {
            Write-LauncherError "Failed to start GUI application"
            return $false
        }
    } catch {
        Write-LauncherError "Error starting GUI application: $($_.Exception.Message)"
        return $false
    }
}

function Show-LauncherHelp {
    Write-Host ""
    Write-Host "ReSet Toolkit GUI Launcher - Usage" -ForegroundColor $Colors.Header
    Write-Host "=================================" -ForegroundColor $Colors.Header
    Write-Host ""
    Write-Host "SYNTAX:" -ForegroundColor $Colors.Info
    Write-Host "  .\Start-ReSetGUI.ps1 [parameters]" -ForegroundColor $Colors.Muted
    Write-Host ""
    Write-Host "PARAMETERS:" -ForegroundColor $Colors.Info
    Write-Host "  -GuiPath <path>     Explicit path to ReSetGUI.ps1" -ForegroundColor $Colors.Muted
    Write-Host "  -Force              Skip version checks and prompts" -ForegroundColor $Colors.Muted
    Write-Host "  -Silent             Suppress console output" -ForegroundColor $Colors.Muted
    Write-Host "  -NoElevation        Don't request administrator privileges" -ForegroundColor $Colors.Muted
    Write-Host "  -Help               Show this help message" -ForegroundColor $Colors.Muted
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor $Colors.Info
    Write-Host "  .\Start-ReSetGUI.ps1" -ForegroundColor $Colors.Muted
    Write-Host "  .\Start-ReSetGUI.ps1 -Force -Silent" -ForegroundColor $Colors.Muted
    Write-Host "  .\Start-ReSetGUI.ps1 -GuiPath 'C:\Custom\ReSetGUI.ps1'" -ForegroundColor $Colors.Muted
    Write-Host ""
}

function Show-TroubleshootingInfo {
    Write-Host ""
    Write-Host "TROUBLESHOOTING:" -ForegroundColor $Colors.Warning
    Write-Host "===============" -ForegroundColor $Colors.Warning
    Write-Host ""
    Write-Host "Common Issues:" -ForegroundColor $Colors.Info
    Write-Host "• GUI script not found: Ensure ReSet Toolkit is properly installed" -ForegroundColor $Colors.Muted
    Write-Host "• Access denied: Run as Administrator or use -NoElevation" -ForegroundColor $Colors.Muted
    Write-Host "• Execution policy: Use 'Set-ExecutionPolicy RemoteSigned'" -ForegroundColor $Colors.Muted
    Write-Host "• .NET errors: Install .NET Framework 4.7.2+" -ForegroundColor $Colors.Muted
    Write-Host ""
    Write-Host "Alternative Launch Methods:" -ForegroundColor $Colors.Info
    Write-Host "• Direct: powershell -ExecutionPolicy Bypass -File gui\ReSetGUI.ps1" -ForegroundColor $Colors.Muted
    Write-Host "• CLI Mode: .\cli\ReSetCLI.ps1" -ForegroundColor $Colors.Muted
    Write-Host "• Installation: .\Install-ReSet.ps1" -ForegroundColor $Colors.Muted
    Write-Host ""
}

# Main execution logic
try {
    # Handle help parameter
    if ($args -contains '-Help' -or $args -contains '--help' -or $args -contains '/?') {
        Show-LauncherHelp
        exit 0
    }
    
    Write-LauncherHeader
    
    # Check administrator privileges
    $isAdmin = Test-AdministratorPrivileges
    if (-not $isAdmin) {
        Write-LauncherWarning "Not running as administrator"
        
        if (-not $NoElevation) {
            Write-LauncherInfo "The ReSet Toolkit requires administrator privileges for full functionality."
            
            if (-not $Silent -and -not $Force) {
                $elevate = Read-Host "Request administrator privileges? (Y/n)"
                if ($elevate -notmatch '^n') {
                    $elevated = Request-Elevation -ScriptPath $MyInvocation.MyCommand.Path
                    if ($elevated) {
                        Write-LauncherSuccess "Launching with elevated privileges"
                        exit 0
                    } else {
                        Write-LauncherWarning "Continuing without elevation"
                    }
                }
            } elseif ($Force) {
                Write-LauncherWarning "Force mode: Continuing without elevation"
            }
        }
    } else {
        Write-LauncherSuccess "Running with administrator privileges"
    }
    
    # Check PowerShell version
    $psCompatibility = Test-PowerShellVersion
    if ($psCompatibility -eq 'Cancelled') {
        Write-LauncherInfo "Launch cancelled by user"
        exit 0
    }
    
    # Find GUI script
    $guiScript = Find-GuiScript
    if (-not $guiScript) {
        Write-LauncherError "GUI script not found"
        Write-LauncherInfo ""
        Write-LauncherInfo "Searched locations:"
        Write-LauncherInfo "• Relative to script: .\gui\ReSetGUI.ps1"
        Write-LauncherInfo "• Current directory: .\ReSetGUI.ps1"
        Write-LauncherInfo "• Environment: `$env:RESET_TOOLKIT_HOME\gui\ReSetGUI.ps1"
        Write-LauncherInfo "• System paths: C:\ReSet\gui\ReSetGUI.ps1"
        Write-LauncherInfo ""
        Write-LauncherInfo "Please ensure the ReSet Toolkit is properly installed."
        Write-LauncherInfo "Run '.\Install-ReSet.ps1' to install or repair the toolkit."
        
        Show-TroubleshootingInfo
        
        if (-not $Silent) {
            Read-Host "Press Enter to exit"
        }
        exit 1
    }
    
    # Validate prerequisites
    $prereqOk = Test-GuiPrerequisites -GuiScriptPath $guiScript
    if (-not $prereqOk) {
        Write-LauncherError "Prerequisites check failed"
        Show-TroubleshootingInfo
        
        if (-not $Silent) {
            Read-Host "Press Enter to exit"
        }
        exit 1
    }
    
    # Launch GUI application
    $launchSuccess = Start-GuiApplication -GuiScriptPath $guiScript
    
    if ($launchSuccess) {
        Write-LauncherSuccess "ReSet Toolkit GUI is now running"
        if (-not $Silent) {
            Write-LauncherInfo "You can now close this console window."
        }
        exit 0
    } else {
        Write-LauncherError "Failed to launch GUI application"
        Show-TroubleshootingInfo
        
        if (-not $Silent) {
            Read-Host "Press Enter to exit"
        }
        exit 1
    }
    
} catch {
    Write-LauncherError "Unexpected error: $($_.Exception.Message)"
    
    if ($_.Exception.InnerException) {
        Write-LauncherError "Inner exception: $($_.Exception.InnerException.Message)"
    }
    
    Write-LauncherInfo "Full error details:"
    Write-Host $_.Exception.ToString() -ForegroundColor $Colors.Muted
    
    Show-TroubleshootingInfo
    
    if (-not $Silent) {
        Read-Host "Press Enter to exit"
    }
    exit 1
}