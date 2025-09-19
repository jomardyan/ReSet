# Script to convert all remaining reset-*.bat files to PowerShell
# This will create basic PowerShell versions maintaining the same functionality

$scriptsPath = $PSScriptRoot
$batFiles = Get-ChildItem -Path $scriptsPath -Filter "reset-*.bat"

foreach ($batFile in $batFiles) {
    $psFileName = $batFile.Name -replace '\.bat$', '.ps1'
    $psFilePath = Join-Path $scriptsPath $psFileName
    
    # Skip if PowerShell version already exists
    if (Test-Path $psFilePath) {
        Write-Host "Skipping $psFileName - already exists" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "Converting $($batFile.Name) to $psFileName..." -ForegroundColor Cyan
    
    # Read the original BAT content
    $batContent = Get-Content $batFile.FullName -Raw
    
    # Extract the script description/title from the BAT file
    $titleMatch = [regex]::Match($batContent, ':: (.+)')
    $scriptDescription = if ($titleMatch.Success) { $titleMatch.Groups[1].Value } else { "Windows Settings Reset Script" }
    
    # Create PowerShell equivalent
    $psContent = @"
# $scriptDescription

param(
    [switch]`$Silent,
    [switch]`$VerifyBackup,
    [string]`$BackupPath
)

# Set window title
`$scriptTitle = (`$batFile.BaseName -replace 'reset-', '') -replace '-', ' '
`$scriptTitle = (Get-Culture).TextInfo.ToTitleCase(`$scriptTitle)
`$Host.UI.RawUI.WindowTitle = "ReSet - `$scriptTitle Reset"

# Import utils module
`$utilsPath = Join-Path `$PSScriptRoot "utils.ps1"
if (Test-Path `$utilsPath) {
    Import-Module `$utilsPath -Force -Global
} else {
    Write-Error "Utils module not found: `$utilsPath"
    exit 1
}

# Initialize global variables from parameters
`$global:SILENT_MODE = `$Silent.IsPresent
`$global:VERIFY_BACKUP = `$VerifyBackup.IsPresent
if (`$BackupPath) { `$global:BACKUP_DIR = `$BackupPath }

Write-LogMessage -Level "INFO" -Message "Starting $($scriptDescription)"
Test-WindowsVersion | Out-Null

# Confirm action (this would need to be customized per script)
if (-not (Confirm-Action -Action "reset settings (please customize this message for the specific script)")) {
    exit 1
}

# TODO: Convert the specific functionality from the BAT file
# This is a template - each script needs its specific implementation

Write-LogMessage -Level "INFO" -Message "This script needs manual conversion from BAT to PowerShell"
Write-Host "This PowerShell script is a template and needs to be manually implemented." -ForegroundColor Yellow
Write-Host "Original BAT file: `$($batFile.FullName)" -ForegroundColor Gray
Write-Host "Please review the BAT file content and implement the PowerShell equivalent." -ForegroundColor Gray

Write-LogMessage -Level "SUCCESS" -Message "$scriptDescription template created"
Write-Host ""
Write-Host "Template created. Manual implementation required." -ForegroundColor Yellow
Write-Host "Log file: `$global:LOG_FILE" -ForegroundColor Cyan

Write-LogMessage -Level "INFO" -Message "$scriptDescription template completed"
exit 0
"@

    # Write the PowerShell template
    $psContent | Out-File -FilePath $psFilePath -Encoding UTF8
    Write-Host "Created template: $psFilePath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Conversion complete. Review and implement each PowerShell script manually." -ForegroundColor Yellow