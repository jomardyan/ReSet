# ReSet Toolkit GUI Demo Script
# Demonstrates the GUI application features and capabilities

param(
    [switch]$ShowFeatures,
    [switch]$TestMode,
    [string]$DemoScript = "all"
)

Write-Host "ReSet Toolkit GUI Demo" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

if ($ShowFeatures) {
    Write-Host "GUI Application Features:" -ForegroundColor Green
    Write-Host "========================" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 Core Features:" -ForegroundColor Yellow
    Write-Host "  • Dynamic script detection and categorization"
    Write-Host "  • Interactive tree view with expandable categories"
    Write-Host "  • Real-time script information and metadata display"
    Write-Host "  • Batch operations with advanced configuration options"
    Write-Host "  • Visual progress tracking and detailed logging"
    Write-Host ""
    Write-Host "🛡️ Safety Features:" -ForegroundColor Yellow
    Write-Host "  • Risk level indicators (Low/Medium/High)"
    Write-Host "  • Restart requirement detection and handling"
    Write-Host "  • Compatibility checking and validation"
    Write-Host "  • Script preview mode with change analysis"
    Write-Host "  • Enhanced confirmation dialogs with detailed information"
    Write-Host ""
    Write-Host "🎨 User Experience:" -ForegroundColor Yellow
    Write-Host "  • Professional Windows Forms interface"
    Write-Host "  • Responsive and resizable layout"
    Write-Host "  • Enhanced tooltips and contextual help"
    Write-Host "  • Color-coded logging and status indicators"
    Write-Host "  • Light/Dark theme support"
    Write-Host ""
    Write-Host "🔧 System Integration:" -ForegroundColor Yellow
    Write-Host "  • INI-based configuration management"
    Write-Host "  • Backup information and restore point integration"
    Write-Host "  • Health monitoring and system validation"
    Write-Host "  • Comprehensive log management and viewing"
    Write-Host "  • Administrative privilege checks"
    Write-Host ""
    return
}

# Check if GUI files exist
$guiPath = Join-Path $PSScriptRoot "gui\ReSetGUI.ps1"
$configPath = Join-Path $PSScriptRoot "gui\GUIConfig.psm1"
$launcherPath = Join-Path $PSScriptRoot "start-gui.bat"

Write-Host "Checking GUI Installation..." -ForegroundColor Yellow

$allFilesExist = $true

if (Test-Path $guiPath) {
    Write-Host "✅ Main GUI application found: ReSetGUI.ps1" -ForegroundColor Green
} else {
    Write-Host "❌ Main GUI application missing: ReSetGUI.ps1" -ForegroundColor Red
    $allFilesExist = $false
}

if (Test-Path $configPath) {
    Write-Host "✅ Configuration module found: GUIConfig.psm1" -ForegroundColor Green
} else {
    Write-Host "❌ Configuration module missing: GUIConfig.psm1" -ForegroundColor Red
    $allFilesExist = $false
}

if (Test-Path $launcherPath) {
    Write-Host "✅ Launcher script found: start-gui.bat" -ForegroundColor Green
} else {
    Write-Host "❌ Launcher script missing: start-gui.bat" -ForegroundColor Red
    $allFilesExist = $false
}

Write-Host ""

if (-not $allFilesExist) {
    Write-Host "Some GUI files are missing. Please ensure all files are properly installed." -ForegroundColor Red
    return
}

# Check PowerShell version
Write-Host "Checking PowerShell Compatibility..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion.Major

if ($psVersion -ge 5) {
    Write-Host "✅ PowerShell $($PSVersionTable.PSVersion) is compatible" -ForegroundColor Green
} elseif ($psVersion -ge 3) {
    Write-Host "⚠️  PowerShell $($PSVersionTable.PSVersion) - Some features may be limited" -ForegroundColor Yellow
} else {
    Write-Host "❌ PowerShell $($PSVersionTable.PSVersion) - Version 3.0+ required" -ForegroundColor Red
    return
}

# Check administrator privileges
Write-Host "Checking Administrator Privileges..." -ForegroundColor Yellow
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if ($isAdmin) {
    Write-Host "✅ Running with administrator privileges" -ForegroundColor Green
} else {
    Write-Host "⚠️  Not running as administrator - Some features may be limited" -ForegroundColor Yellow
}

# Check scripts directory
Write-Host "Checking Scripts Directory..." -ForegroundColor Yellow
$scriptsPath = Join-Path $PSScriptRoot "scripts"

if (Test-Path $scriptsPath) {
    $scriptFiles = Get-ChildItem -Path $scriptsPath -Filter "reset-*.bat"
    Write-Host "✅ Scripts directory found with $($scriptFiles.Count) reset scripts" -ForegroundColor Green
    
    if ($scriptFiles.Count -gt 0) {
        Write-Host "   Sample scripts detected:" -ForegroundColor Gray
        $scriptFiles | Select-Object -First 5 | ForEach-Object {
            Write-Host "   • $($_.Name)" -ForegroundColor Gray
        }
        if ($scriptFiles.Count -gt 5) {
            Write-Host "   ... and $($scriptFiles.Count - 5) more scripts" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "❌ Scripts directory not found: $scriptsPath" -ForegroundColor Red
}

Write-Host ""

if ($TestMode) {
    Write-Host "Test Mode: Analyzing GUI Components..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Test configuration loading
        Write-Host "Testing configuration module..." -ForegroundColor Yellow
        Import-Module $configPath -Force
        
        if (Get-Command "Get-GUIConfiguration" -ErrorAction SilentlyContinue) {
            $config = Get-GUIConfiguration
            Write-Host "✅ Configuration module loaded successfully" -ForegroundColor Green
            Write-Host "   Theme: $($config.UI.Theme)" -ForegroundColor Gray
            Write-Host "   Window Size: $($config.UI.WindowWidth)x$($config.UI.WindowHeight)" -ForegroundColor Gray
        }
        
        # Test script metadata parsing
        if ($scriptFiles.Count -gt 0 -and (Get-Command "Get-ScriptMetadata" -ErrorAction SilentlyContinue)) {
            Write-Host "Testing script metadata parsing..." -ForegroundColor Yellow
            $testScript = $scriptFiles[0]
            $metadata = Get-ScriptMetadata -ScriptPath $testScript.FullName
            Write-Host "✅ Script metadata parsing functional" -ForegroundColor Green
        }
        
        # Test compatibility checking
        if (Get-Command "Test-ScriptCompatibility" -ErrorAction SilentlyContinue) {
            Write-Host "Testing compatibility checking..." -ForegroundColor Yellow
            $compat = Test-ScriptCompatibility -ScriptPath $testScript.FullName
            Write-Host "✅ Compatibility checking functional" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "❌ Error during testing: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "GUI Demo Complete!" -ForegroundColor Cyan
Write-Host ""
Write-Host "To start the GUI application:" -ForegroundColor Green
Write-Host "  1. Run as Administrator: start-gui.bat" -ForegroundColor White
Write-Host "  2. Or direct PowerShell: PowerShell -ExecutionPolicy Bypass -File `"gui\ReSetGUI.ps1`"" -ForegroundColor White
Write-Host ""
Write-Host "For detailed feature information:" -ForegroundColor Green
Write-Host "  PowerShell -File demo-gui.ps1 -ShowFeatures" -ForegroundColor White
Write-Host ""
Write-Host "For comprehensive testing:" -ForegroundColor Green
Write-Host "  PowerShell -File demo-gui.ps1 -TestMode" -ForegroundColor White