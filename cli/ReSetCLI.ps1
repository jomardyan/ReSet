# ReSet Toolkit - Console Administration Interface
# Interactive PowerShell console for Windows Settings Reset Toolkit
# Administrator-focused with dynamic script detection and responsive interface
# Compatibility: Windows PowerShell 5.1+ or PowerShell 7+ on Windows

[CmdletBinding()]
param(
    [switch]$NonInteractive,
    [string]$Search,
    [string[]]$Categories,
    [switch]$RunBatch,
    [switch]$ExportReport,
    [switch]$QuickScan,
    [switch]$DebugMode
)

# region Setup and Configuration -------------------------------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = if ($DebugMode) { 'Continue' } else { 'Stop' }

# Enhanced console configuration for admin interface
if ($Host.UI.RawUI) {
    try {
        $Host.UI.RawUI.WindowTitle = "ReSet Toolkit - Admin Console"
        $Host.UI.RawUI.BackgroundColor = "Black"
        $Host.UI.RawUI.ForegroundColor = "White"
    } catch {
        # Ignore if in non-interactive mode
    }
}

# Color scheme for professional admin interface
$Global:Colors = @{ 
    Primary = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red'; 
    Title = 'Magenta'; Header = 'Blue'; Muted = 'DarkGray'; Emphasis = 'White';
    Critical = 'DarkRed'; Info = 'DarkCyan'; Highlight = 'DarkYellow'
}

# Enhanced output functions with formatting
function Write-AdminHeader($msg, $color = $Global:Colors.Header) { 
    Write-Host ("`n" + "=" * 80) -ForegroundColor $color
    Write-Host " $msg" -ForegroundColor $color
    Write-Host ("=" * 80) -ForegroundColor $color
}
function Write-Info($msg){ Write-Host "[INFO] $msg" -ForegroundColor $Global:Colors.Info }
function Write-Success($msg){ Write-Host "[SUCCESS] $msg" -ForegroundColor $Global:Colors.Success }
function Write-Warn($msg){ Write-Host "[WARNING] $msg" -ForegroundColor $Global:Colors.Warning }
function Write-ErrorMsg($msg){ Write-Host "[ERROR] $msg" -ForegroundColor $Global:Colors.Error }
function Write-Title($msg){ Write-Host $msg -ForegroundColor $Global:Colors.Title }
function Write-Muted($msg){ Write-Host $msg -ForegroundColor $Global:Colors.Muted }
function Write-Critical($msg){ Write-Host "[CRITICAL] $msg" -ForegroundColor $Global:Colors.Critical }
function Write-Highlight($msg){ Write-Host $msg -ForegroundColor $Global:Colors.Highlight }

# Paths
$ScriptRoot = Split-Path -Parent $PSCommandPath
$ResetRoot = Split-Path -Parent $ScriptRoot
$ScriptsPath = Join-Path $ResetRoot 'scripts'
$LogsPath = Join-Path $ResetRoot 'logs'
$BackupsPath = Join-Path $ResetRoot 'backups'
$BatchScriptPath = Join-Path $ResetRoot 'batch-reset.bat'
$ConfigPath = Join-Path $ResetRoot 'config.ini'

# Import GUI configuration module for shared helpers
$GUIConfigModule = Join-Path (Join-Path $ResetRoot 'gui') 'GUIConfig.psm1'
if (Test-Path $GUIConfigModule) {
    Import-Module $GUIConfigModule -Force -ErrorAction SilentlyContinue | Out-Null
}

# Load config if available
$Global:GUIConfig = $null
try {
    if (Get-Command Get-GUIConfiguration -ErrorAction SilentlyContinue) {
        $Global:GUIConfig = Get-GUIConfiguration
    }
} catch {}

# Category map (same as GUI)
$ScriptCategories = [ordered]@{
    'Language & Regional' = @('reset-language-settings','reset-datetime')
    'Display & Audio' = @('reset-display','reset-audio','reset-fonts')
    'Network & Connectivity' = @('reset-network','reset-windows-update','reset-browser')
    'Security & Privacy' = @('reset-uac','reset-privacy','reset-defender')
    'Search & Interface' = @('reset-search','reset-startmenu','reset-shell')
    'File Management' = @('reset-file-associations','reset-fonts')
    'Performance & Power' = @('reset-power','reset-performance')
    'Applications & Store' = @('reset-browser','reset-store')
    'Input & Accessibility' = @('reset-input-devices')
    'System Components' = @('reset-features','reset-environment','reset-registry')
}

if ($Global:GUIConfig -and $Global:GUIConfig.Categories.DisplayOrder) {
    $ordered = [ordered]@{}
    foreach ($cat in $Global:GUIConfig.Categories.DisplayOrder -split ',') {
        $c = $cat.Trim()
        if ($ScriptCategories.Contains($c)) { $ordered[$c] = $ScriptCategories[$c] }
    }
    foreach ($k in $ScriptCategories.Keys) { if (-not $ordered.Contains($k)) { $ordered[$k] = $ScriptCategories[$k] } }
    $ScriptCategories = $ordered
}

# Cache
$Global:AvailableScripts = $null
$Global:LastScan = $null

# Enhanced utilities for admin interface
function Test-AdminRights {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Critical 'Administrator privileges required for ReSet Toolkit operations'
        Write-Host "Please restart PowerShell as Administrator or use:" -ForegroundColor Yellow
        Write-Host "  Start-Process PowerShell -Verb RunAs" -ForegroundColor Cyan
        exit 1
    }
}

function Confirm-Action([string]$Message, [switch]$DefaultNo, [string]$RiskLevel = "Medium"){
    $riskColor = switch ($RiskLevel) {
        "Low" { $Global:Colors.Success }
        "Medium" { $Global:Colors.Warning }
        "High" { $Global:Colors.Error }
        default { $Global:Colors.Warning }
    }
    
    Write-Host "`n[CONFIRMATION REQUIRED]" -ForegroundColor $riskColor
    Write-Host "Risk Level: $RiskLevel" -ForegroundColor $riskColor
    Write-Host $Message -ForegroundColor White
    
    $choices = @(
        New-Object System.Management.Automation.Host.ChoiceDescription '&Yes','Proceed with action'
        New-Object System.Management.Automation.Host.ChoiceDescription '&No','Cancel action'
    )
    $default = if($DefaultNo){1}else{0}
    $selection = $Host.UI.PromptForChoice('Confirm Action', 'Do you want to proceed?', $choices, $default)
    return ($selection -eq 0)
}

function Show-ProgressBar([string]$Activity, [int]$Total, [scriptblock]$ScriptBlock) {
    if ($Total -lt 1) { $Total = 1 }
    Write-Host "`n[$Activity]" -ForegroundColor $Global:Colors.Primary
    
    for ($i = 1; $i -le $Total; $i++) {
        $percent = [math]::Round(($i / $Total) * 100)
        $completed = [math]::Floor($percent / 2)
        $bar = ('#' * $completed).PadRight(50, '-')
        
        Write-Host "`r[$bar] $percent% " -NoNewline -ForegroundColor $Global:Colors.Highlight
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`n"
    
    if ($ScriptBlock) { & $ScriptBlock }
}

function Show-SystemInfo {
    Write-AdminHeader "SYSTEM INFORMATION"
    
    $info = @{
        'Computer Name' = $env:COMPUTERNAME
        'User Name' = $env:USERNAME
        'Domain' = $env:USERDOMAIN
        'OS Version' = [System.Environment]::OSVersion.VersionString
        'PowerShell Version' = "$($PSVersionTable.PSVersion)"
        'Architecture' = [System.Environment]::Is64BitOperatingSystem ? "64-bit" : "32-bit"
        'Current Time' = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        'Uptime' = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    }
    
    $info.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host ("{0,-20}: {1}" -f $_.Key, $_.Value) -ForegroundColor White
    }
}

# endregion ---------------------------------------------------------------------

# region Script Discovery --------------------------------------------------------
function Get-AvailableScripts {
    param([switch]$Force)
    if (-not $Force -and $Global:AvailableScripts -and $Global:LastScan -and ((Get-Date) - $Global:LastScan).TotalMinutes -lt 5) {
        return $Global:AvailableScripts
    }

    $scripts = @{}
    if (-not (Test-Path $ScriptsPath)) { return $scripts }

    $files = Get-ChildItem -Path $ScriptsPath -Filter 'reset-*.bat' -ErrorAction SilentlyContinue
    $count = $files.Count
    $idx = 0

    foreach($f in $files){
        $idx++
        Write-Host ("Scanning {0}/{1}: {2}" -f $idx,$count,$f.Name) -ForegroundColor $colors.Muted

        $name = $f.BaseName
        $display = ($name -replace 'reset-','' -replace '-',' ')
        $display = (Get-Culture).TextInfo.ToTitleCase($display.ToLower())

        $metadata = $null
        if (Get-Command Get-ScriptMetadata -ErrorAction SilentlyContinue){
            try { $metadata = Get-ScriptMetadata -ScriptPath $f.FullName } catch {}
            if ($metadata -and $metadata.DisplayName) { $display = $metadata.DisplayName }
        }

        $desc = 'Windows settings reset script'
        $risk = 'Medium'
        $restart = $false
        try {
            $head = Get-Content $f.FullName -TotalCount 20
            foreach($line in $head){
                if ($line -match '^:: (.+)$'){
                    $c = $matches[1].Trim()
                    if ($c -match '^Description: (.+)$'){ $desc = $matches[1] }
                    elseif ($c -match '^RiskLevel: (Low|Medium|High)$'){ $risk = $matches[1] }
                    elseif ($c -match '^RequiresRestart: (true|false)$'){ $restart = ($matches[1] -eq 'true') }
                } elseif ($line -match '::' -and $line -match 'Reset' -and $desc -eq 'Windows settings reset script'){
                    $desc = ($line -replace '::','').Trim()
                }
            }
        } catch {}

        $scripts[$name] = [ordered]@{
            Name = $name
            DisplayName = $display
            Description = $desc
            FilePath = $f.FullName
            Category = (Get-ScriptCategory $name)
            LastModified = $f.LastWriteTime
            RiskLevel = $risk
            RequiresRestart = $restart
            FileSize = $f.Length
            Metadata = $metadata
        }
    }

    $Global:AvailableScripts = $scripts
    $Global:LastScan = Get-Date
    return $scripts
}

function Get-ScriptCategory($scriptName){
    foreach($cat in $ScriptCategories.Keys){ if ($ScriptCategories[$cat] -contains $scriptName){ return $cat } }
    return 'Other'
}

# endregion ---------------------------------------------------------------------

# region Views & Menus -----------------------------------------------------------
function Show-Banner {
    Clear-Host
    Write-Title '============================================='
    Write-Title '   ReSet Toolkit - Console Edition (v2.1)    '
    Write-Title '============================================='
    Write-Muted ("Root: {0}" -f $ResetRoot)
    Write-Host
}

function Show-MainMenu {
    while ($true) {
        Show-Banner
        Show-SystemInfo
        
        $scripts = Get-AvailableScripts
        Write-AdminHeader "ADMINISTRATOR CONSOLE - MAIN MENU"
        Write-Info ("Scripts detected: {0}" -f $scripts.Count)
        Write-Host
        
        # Main operations
        Write-Title "SCRIPT OPERATIONS:"
        Write-Host "  1) Browse scripts by category" -ForegroundColor White
        Write-Host "  2) Search and filter scripts" -ForegroundColor White
        Write-Host "  3) Run individual script" -ForegroundColor White
        Write-Host "  4) Batch run by categories" -ForegroundColor Yellow
        Write-Host "  5) Preview script changes" -ForegroundColor Cyan
        Write-Host
        
        # System tools
        Write-Title "SYSTEM ADMINISTRATION:"
        Write-Host "  6) System health check" -ForegroundColor Green
        Write-Host "  7) Validate installation" -ForegroundColor Green
        Write-Host "  8) System cleanup" -ForegroundColor Yellow
        Write-Host "  9) Backup manager" -ForegroundColor Cyan
        Write-Host
        
        # Information and reports
        Write-Title "INFORMATION & REPORTS:"
        Write-Host " 10) View latest log" -ForegroundColor White
        Write-Host " 11) Configuration viewer" -ForegroundColor White
        Write-Host " 12) Export detailed report" -ForegroundColor Cyan
        Write-Host " 13) Statistics dashboard" -ForegroundColor Magenta
        Write-Host
        
        # Utilities
        Write-Title "UTILITIES:"
        Write-Host " 14) Refresh script cache" -ForegroundColor DarkCyan
        Write-Host " 15) Quick system scan" -ForegroundColor Yellow
        Write-Host "  0) Exit" -ForegroundColor Red
        Write-Host
        
        $choice = Read-Host "Select option [0-15]"
        switch ($choice) {
            '1' { Show-ByCategory }
            '2' { Search-Scripts }
            '3' { Invoke-ScriptInteractive }
            '4' { Invoke-BatchInteractive }
            '5' { Show-ScriptInteractivePreview }
            '6' { Show-SystemTools 'health-check' }
            '7' { Show-SystemTools 'validate' }
            '8' { Show-SystemTools 'cleanup' }
            '9' { Show-BackupManager }
            '10' { Show-LatestLog }
            '11' { Show-Configuration }
            '12' { Export-Report }
            '13' { Show-Statistics }
            '14' { Update-ScriptCache }
            '15' { Start-QuickScan }
            '0' { 
                Write-Info "Exiting ReSet Toolkit Admin Console..."
                break 
            }
            default { 
                Write-Warn "Invalid choice: $choice"
                Start-Sleep -Milliseconds 800 
            }
        }
    }
}

function Show-ByCategory {
    Show-Banner
    $scripts = Get-AvailableScripts
    $i = 0
    foreach($cat in $ScriptCategories.Keys){
        $group = $scripts.Values | Where-Object { $_.Category -eq $cat }
        if ($group){
            Write-Title ("[{0}] {1} ({2})" -f (++$i), $cat, $group.Count)
            $group | Sort-Object DisplayName | Format-Table DisplayName,RiskLevel,RequiresRestart,LastModified -AutoSize
            Write-Host
        }
    }
    Write-Muted 'Press Enter to return to main menu'
    [void](Read-Host)
}

function Search-Scripts {
    Show-Banner
    $query = Read-Host 'Enter search text'
    $scripts = Get-AvailableScripts
    $searchResults = $scripts.Values | Where-Object { $_.DisplayName -like "*${query}*" -or $_.Description -like "*${query}*" }
    if (-not $searchResults) { Write-Warn 'No matches found'; Start-Sleep 1; return }
    Write-Info ("Found {0} matches:" -f $searchResults.Count)
    $searchResults | Sort-Object DisplayName | Format-Table DisplayName,Category,RiskLevel,RequiresRestart,LastModified -AutoSize
    Write-Host
    Write-Muted 'Press Enter to return'
    [void](Read-Host)
}

function Select-Script($prompt){
    $scripts = Get-AvailableScripts
    $ordered = $scripts.Values | Sort-Object Category, DisplayName
    $idx = 0
    $map = @{}
    Write-Info $prompt
    foreach($s in $ordered){
        $idx++
        $map[$idx] = $s
        Write-Host ("{0,3}) {1}  [{2}]  Risk:{3} Restart:{4}" -f $idx,$s.DisplayName,$s.Category,$s.RiskLevel,($s.RequiresRestart))
    }
    Write-Host
    $sel = Read-Host 'Enter number (or blank to cancel)'
    if ([string]::IsNullOrWhiteSpace($sel)) { return $null }
    if (-not ($sel -as [int]) -or -not $map.ContainsKey([int]$sel)) { Write-Warn 'Invalid selection'; return $null }
    return $map[[int]$sel]
}

# endregion ---------------------------------------------------------------------

# region Actions ----------------------------------------------------------------
function Show-ScriptInteractivePreview {
    $s = Select-Script 'Select a script to preview:'
    if ($null -eq $s) { return }
    Show-ScriptPreview -Script $s
    Write-Muted 'Press Enter to return'
    [void](Read-Host)
}

function Invoke-ScriptInteractive {
    $s = Select-Script 'Select a script to run:'
    if ($null -eq $s) { return }
    Invoke-SingleScript -Script $s
}

function Invoke-BatchInteractive {
    Show-Banner
    Write-Info 'Select categories to include (comma-separated numbers)'
    $i=0; $map=@{}
    foreach($cat in $ScriptCategories.Keys){ $i++; $map[$i]=$cat; Write-Host ("{0}) {1}" -f $i,$cat) }
    $inp = Read-Host 'Your selection'
    if ([string]::IsNullOrWhiteSpace($inp)) { return }
    $nums = $inp -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -as [int] }
    $chosen = @(); foreach($n in $nums){ $k=[int]$n; if ($map.ContainsKey($k)){ $chosen+= $map[$k] } }
    if (-not $chosen){ Write-Warn 'No valid categories selected'; Start-Sleep 1; return }
    $restore = Read-Host 'Create restore point? (y/N)'
    $silent = Read-Host 'Silent mode? (y/N)'
    Invoke-BatchOperation -Categories $chosen -CreateRestorePoint:($restore -match '^(y|yes)$') -Silent:($silent -match '^(y|yes)$')
}

function Show-SystemTools($defaultTool = $null) {
    if ($defaultTool) {
        Start-SystemTool $defaultTool
        return
    }
    
    Show-Banner
    Write-AdminHeader "SYSTEM ADMINISTRATION TOOLS"
    Write-Host '1) Run comprehensive health check' -ForegroundColor Green
    Write-Host '2) Validate ReSet installation' -ForegroundColor Blue
    Write-Host '3) System cleanup and maintenance' -ForegroundColor Yellow
    Write-Host '4) Create system restore point' -ForegroundColor Cyan
    Write-Host '0) Back to main menu' -ForegroundColor Gray
    Write-Host
    $c = Read-Host 'Choose system tool'
    switch($c){
        '1' { Start-SystemTool 'health-check' }
        '2' { Start-SystemTool 'validate' }
        '3' { Start-SystemTool 'cleanup' }
        '4' { Start-RestorePoint }
        default { return }
    }
}

function Start-QuickScan {
    Write-AdminHeader "QUICK SYSTEM SCAN"
    Write-Info "Performing rapid system assessment..."
    
    Show-ProgressBar "System Scan" 10 {
        # Quick system checks
        $issues = @()
        
        # Check disk space
        $systemDrive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
        $freeSpacePercent = ($systemDrive.FreeSpace / $systemDrive.Size) * 100
        if ($freeSpacePercent -lt 10) {
            $issues += "Low disk space: {0:F1}% free on {1}" -f $freeSpacePercent, $systemDrive.DeviceID
        }
        
        # Check memory usage
        $totalMemory = (Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory
        $availableMemory = (Get-WmiObject Win32_OperatingSystem).AvailablePhysicalMemory
        $memoryUsage = (($totalMemory - ($availableMemory * 1KB)) / $totalMemory) * 100
        if ($memoryUsage -gt 85) {
            $issues += "High memory usage: {0:F1}%" -f $memoryUsage
        }
        
        # Check critical services
        $criticalServices = @('EventLog', 'Themes', 'AudioSrv', 'BITS')
        foreach ($service in $criticalServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -ne 'Running') {
                $issues += "Service not running: $service"
            }
        }
    }
    
    Write-Host
    if ($issues.Count -eq 0) {
        Write-Success "System scan completed - No critical issues detected"
    } else {
        Write-Warn "System scan found $($issues.Count) potential issues:"
        foreach ($issue in $issues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
    }
    
    Write-Host
    Write-Muted 'Press Enter to continue'
    [void](Read-Host)
}

function Start-RestorePoint {
    Write-Info "Creating system restore point..."
    try {
        $restoreName = "ReSet Toolkit - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Checkpoint-Computer -Description $restoreName -RestorePointType "MODIFY_SETTINGS"
        Write-Success "Restore point created: $restoreName"
    } catch {
        Write-ErrorMsg "Failed to create restore point: $($_.Exception.Message)"
    }
    Start-Sleep 2
}

function Show-BackupManager {
    Show-Banner
    if (-not (Test-Path $BackupsPath)) { Write-Warn "Backups folder not found: $BackupsPath"; Start-Sleep 1; return }
    $files = Get-ChildItem -Path $BackupsPath -Recurse | Sort-Object LastWriteTime -Descending
    if (-not $files){ Write-Warn 'No backup files found'; Start-Sleep 1; return }
    $files | Select-Object Name,Extension,Length,@{n='Modified';e={$_.LastWriteTime}},FullName | Format-Table -AutoSize
    Write-Host
    Write-Muted 'Press Enter to return'
    [void](Read-Host)
}

function Show-LatestLog {
    Show-Banner
    if (-not (Test-Path $LogsPath)) { Write-Warn "Logs folder not found: $LogsPath"; Start-Sleep 1; return }
    $log = Get-ChildItem -Path $LogsPath -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $log) { Write-Warn 'No logs found'; Start-Sleep 1; return }
    Write-Info ("Showing: {0}" -f $log.FullName)
    Get-Content -Path $log.FullName -Tail 200 | ForEach-Object { Write-Host $_ }
    Write-Host
    Write-Muted 'Press Enter to return'
    [void](Read-Host)
}

function Show-Configuration {
    Show-Banner
    if (-not $Global:GUIConfig) { Write-Warn 'No configuration module loaded'; Start-Sleep 1; return }
    $Global:GUIConfig.GetEnumerator() | ForEach-Object {
        Write-Title ("[{0}]" -f $_.Key)
        $_.Value.GetEnumerator() | Sort-Object Name | Format-Table Name, Value -AutoSize
        Write-Host
    }
    Write-Muted 'Press Enter to return'
    [void](Read-Host)
}

function Export-Report {
    Show-Banner
    $scripts = Get-AvailableScripts -Force
    $data = $scripts.Values | Select-Object DisplayName,Category,RiskLevel,RequiresRestart,LastModified,FileSize,Description,FilePath
    $default = Join-Path $ResetRoot ("ReSet_Scripts_Report_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $path = Read-Host "Enter report path (default: $default)"
    if ([string]::IsNullOrWhiteSpace($path)) { $path = $default }
    $data | Export-Csv -Path $path -NoTypeInformation
    Write-Success "Report exported: $path"
    Start-Sleep 1
}

function Show-Statistics {
    Show-Banner
    $scripts = Get-AvailableScripts
    $total = $scripts.Count
    $risk = @{ Low=0; Medium=0; High=0 }
    $restart = 0
    $sizes = 0
    foreach($s in $scripts.Values){
        if ($risk.ContainsKey($s.RiskLevel)){ $risk[$s.RiskLevel]++ }
        if ($s.RequiresRestart){ $restart++ }
        if ($s.FileSize){ $sizes += $s.FileSize }
    }
    Write-Title 'Overview'
    [pscustomobject]@{ TotalScripts=$total; RestartRequired=$restart; TotalSizeKB=[math]::Round($sizes/1KB,2) } | Format-Table -AutoSize
    Write-Host
    Write-Title 'By Risk Level'
    $risk.GetEnumerator() | Sort-Object Name | ForEach-Object { 
        [pscustomobject]@{ Risk=$_.Key; Count=$_.Value; Pct= if($total){ [math]::Round(($_.Value/$total)*100,1) } else {0} }
    } | Format-Table -AutoSize
    Write-Host
    Write-Title 'By Category'
    $byCat = @{}
    foreach($s in $scripts.Values){ if($byCat.ContainsKey($s.Category)){ $byCat[$s.Category]++ } else { $byCat[$s.Category]=1 } }
    $byCat.GetEnumerator() | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{ Category=$_.Key; Count=$_.Value; Pct= if($total){ [math]::Round(($_.Value/$total)*100,1) } else {0} }
    } | Format-Table -AutoSize
    Write-Host
    Write-Muted 'Press Enter to return'
    [void](Read-Host)
}

function Refresh-Data { Get-AvailableScripts -Force | Out-Null; Write-Success 'Refreshed'; Start-Sleep -Milliseconds 500 }

function Show-ScriptPreview {
    param([Parameter(Mandatory)][hashtable]$Script)
    Show-Banner
    Write-Title $Script.DisplayName
    Write-Host $Script.Description
    Write-Host
    Write-Info ("Risk: {0}    Restart: {1}" -f $Script.RiskLevel,$Script.RequiresRestart)
    Write-Muted ("Path: {0}" -f $Script.FilePath)
    Write-Muted ("Modified: {0}" -f $Script.LastModified)
    Write-Host
    Write-Title 'Detected Operations'
    try {
        $content = Get-Content $Script.FilePath
        $reg = @(); $file = @(); $svc = @()
        foreach($l in $content){
            $t = $l.Trim()
            if ($t -match '^(reg )(?:(add|delete))' -and -not $t.StartsWith('::')){ $reg += $t }
            elseif ($t -match '^(del|copy|move|xcopy) ' -and -not $t.StartsWith('::')){ $file += $t }
            elseif ($t -match '^(sc )(?:(start|stop|config))' -and -not $t.StartsWith('::')){ $svc += $t }
        }
        if ($reg.Count){ Write-Host "Registry ($($reg.Count))" -ForegroundColor $Global:Colors.Emphasis; $reg | Select-Object -First 10 | ForEach-Object { Write-Host '  • ' $_ } }
        if ($file.Count){ Write-Host "Files ($($file.Count))" -ForegroundColor $Global:Colors.Emphasis; $file | Select-Object -First 10 | ForEach-Object { Write-Host '  • ' $_ } }
        if ($svc.Count){ Write-Host "Services ($($svc.Count))" -ForegroundColor $Global:Colors.Emphasis; $svc | Select-Object -First 10 | ForEach-Object { Write-Host '  • ' $_ } }
        if (-not $reg.Count -and -not $file.Count -and -not $svc.Count){ Write-Warn 'No basic operations detected (script may use complex logic).' }
    } catch { Write-ErrorMsg $_.Exception.Message }
}

function Invoke-SingleScript {
    param([Parameter(Mandatory)][hashtable]$Script)
    $msg = "Run: {0}`nRisk: {1}`n{2}" -f $Script.DisplayName,$Script.RiskLevel,($(if($Script.RequiresRestart){'Restart required.'}else{''}))  
    if (-not (Confirm-Action -Message $msg -DefaultNo -RiskLevel $Script.RiskLevel)) { return }
    Write-Info "Starting script..."
    try {
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$($Script.FilePath)`"" -WindowStyle Hidden -PassThru
        $p.WaitForExit()
        if ($p.ExitCode -eq 0){ Write-Success 'Completed successfully' } else { Write-ErrorMsg ("Failed with exit code {0}" -f $p.ExitCode) }
    } catch { Write-ErrorMsg $_.Exception.Message }
}

function Invoke-BatchOperation {
    param([string[]]$Categories,[switch]$CreateRestorePoint,[switch]$Silent)
    if (-not (Test-Path $BatchScriptPath)) { Write-ErrorMsg "batch-reset.bat not found: $BatchScriptPath"; return }
    $batchArgs = @('--categories', '"' + ($Categories -join ',') + '"')
    if ($CreateRestorePoint){ $batchArgs += '--create-restore-point' }
    if ($Silent){ $batchArgs += '--silent' }
    $cmdline = "/c `"$BatchScriptPath`" " + ($batchArgs -join ' ')
    if (-not (Confirm-Action -Message ("Run batch for: {0}?" -f ($Categories -join ', ')) -DefaultNo -RiskLevel "High")) { return }
    try {
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdline -WindowStyle Normal -PassThru
        $p.WaitForExit()
        if ($p.ExitCode -eq 0){ Write-Success 'Batch completed' } else { Write-ErrorMsg ("Batch failed with exit code {0}" -f $p.ExitCode) }
    } catch { Write-ErrorMsg $_.Exception.Message }
}

function Update-ScriptCache { Get-AvailableScripts -Force | Out-Null; Write-Success 'Script cache refreshed'; Start-Sleep -Milliseconds 500 }

function Run-SingleScript {
    param([Parameter(Mandatory)][hashtable]$Script)
    $msg = "Run: {0}`nRisk: {1}`n{2}" -f $Script.DisplayName,$Script.RiskLevel,($(if($Script.RequiresRestart){'Restart required.'}else{''}))
    if (-not (Confirm-Action -Message $msg -DefaultNo)) { return }
    Write-Info "Starting script..."
    try {
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$($Script.FilePath)`"" -WindowStyle Hidden -PassThru
        $p.WaitForExit()
        if ($p.ExitCode -eq 0){ Write-Success 'Completed successfully' } else { Write-ErrorMsg ("Failed with exit code {0}" -f $p.ExitCode) }
    } catch { Write-ErrorMsg $_.Exception.Message }
}

function Run-BatchOperation {
    param([string[]]$Categories,[switch]$CreateRestorePoint,[switch]$Silent)
    if (-not (Test-Path $BatchScriptPath)) { Write-ErrorMsg "batch-reset.bat not found: $BatchScriptPath"; return }
    $batchArgs = @('--categories', '"' + ($Categories -join ',') + '"')
    if ($CreateRestorePoint){ $batchArgs += '--create-restore-point' }
    if ($Silent){ $batchArgs += '--silent' }
    $cmdline = "/c `"$BatchScriptPath`" " + ($batchArgs -join ' ')
    if (-not (Confirm-Action -Message ("Run batch for: {0}?" -f ($Categories -join ', ')) -DefaultNo)) { return }
    try {
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList $cmdline -WindowStyle Normal -PassThru
        $p.WaitForExit()
        if ($p.ExitCode -eq 0){ Write-Success 'Batch completed' } else { Write-ErrorMsg ("Batch failed with exit code {0}" -f $p.ExitCode) }
    } catch { Write-ErrorMsg $_.Exception.Message }
}

function Start-SystemTool($tool){
    $toolPath = Join-Path $ResetRoot ("{0}.bat" -f $tool)
    if (-not (Test-Path $toolPath)) { Write-ErrorMsg "Tool not found: $toolPath"; return }
    try {
        $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$toolPath`"" -WindowStyle Normal -PassThru
        $p.WaitForExit()
        Write-Success ("Tool finished: {0}" -f $tool)
    } catch { Write-ErrorMsg $_.Exception.Message }
}

# endregion ---------------------------------------------------------------------

# region Entry Point and Main Application ----------------------------------------
function Start-ReSetCLI {
    # Initialize admin console
    Test-AdminRights
    
    # Quick initialization
    Write-Host "Initializing ReSet Toolkit Admin Console..." -ForegroundColor $Global:Colors.Primary
    Get-AvailableScripts | Out-Null
    
    # Handle command line parameters
    if ($PSBoundParameters.ContainsKey('Search')) {
        Search-Scripts; return
    }
    if ($RunBatch -and $Categories) {
        Invoke-BatchOperation -Categories $Categories; return
    }
    if ($ExportReport) { 
        Export-Report; return 
    }
    if ($QuickScan) {
        Start-QuickScan; return
    }
    
    # Start interactive mode unless non-interactive
    if ($NonInteractive) { 
        Write-Info 'Non-interactive mode completed.'
        return 
    }
    
    # Main interactive console
    try {
        Show-MainMenu
    } catch {
        Write-Critical "Critical error in admin console: $($_.Exception.Message)"
        if ($DebugMode) {
            Write-Host $_.ScriptStackTrace -ForegroundColor Red
        }
    } finally {
        Write-Host "`nReSet Toolkit Admin Console session ended." -ForegroundColor $Global:Colors.Muted
    }
}

# Start the administrative console
Start-ReSetCLI
# endregion ---------------------------------------------------------------------
