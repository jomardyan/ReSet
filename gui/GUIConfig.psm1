# ReSet Toolkit GUI Configuration Module
# Handles dynamic configuration loading and GUI customization

# Helper function to parse INI files
function Read-IniFile {
    param(
        [string]$FilePath
    )
    
    $ini = @{}
    $currentSection = ""
    
    if (Test-Path $FilePath) {
        $content = Get-Content $FilePath
        
        foreach ($line in $content) {
            $line = $line.Trim()
            
            # Skip empty lines and comments
            if ($line -eq "" -or $line.StartsWith("#") -or $line.StartsWith(";")) {
                continue
            }
            
            # Section header
            if ($line -match '^\[(.+)\]$') {
                $currentSection = $matches[1]
                $ini[$currentSection] = @{}
            }
            # Key-value pair
            elseif ($line -match '^(.+?)=(.*)$' -and $currentSection -ne "") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $ini[$currentSection][$key] = $value
            }
        }
    }
    
    return $ini
}

# Function to get GUI configuration
function Get-GUIConfiguration {
    $configPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) "config.ini"
    $config = Read-IniFile -FilePath $configPath
    
    # Default configuration
    $defaultConfig = @{
        UI = @{
            Theme = "Light"
            AutoRefresh = "true"
            ShowTooltips = "true"
            ConfirmActions = "true"
            LogLevel = "INFO"
            WindowWidth = "1200"
            WindowHeight = "800"
        }
        Advanced = @{
            EnableDebugMode = "false"
            MaxLogEntries = "1000"
            AutoBackup = "true"
            BackupRetentionDays = "30"
        }
        Categories = @{
            DisplayOrder = "Language & Regional,Display & Audio,Network & Connectivity,Security & Privacy,Search & Interface,File Management,Performance & Power,Applications & Store,Input & Accessibility,System Components"
        }
    }
    
    # Merge with loaded configuration
    if ($config.Count -gt 0) {
        foreach ($section in $defaultConfig.Keys) {
            if ($config.ContainsKey($section)) {
                foreach ($key in $config[$section].Keys) {
                    $defaultConfig[$section][$key] = $config[$section][$key]
                }
            }
        }
    }
    
    return $defaultConfig
}

# Function to apply theme
function Set-GUITheme {
    param(
        [string]$Theme,
        [System.Windows.Forms.Form]$Form
    )
    
    switch ($Theme.ToLower()) {
        "dark" {
            $backgroundColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
            $foregroundColor = [System.Drawing.Color]::White
            $accentColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        }
        "light" {
            $backgroundColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
            $foregroundColor = [System.Drawing.Color]::Black
            $accentColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        }
        default {
            $backgroundColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
            $foregroundColor = [System.Drawing.Color]::Black
            $accentColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        }
    }
    
    # Apply theme to form
    $Form.BackColor = $backgroundColor
    $Form.ForeColor = $foregroundColor
    
    # Apply theme to all controls recursively
    Apply-ThemeToControls -Controls $Form.Controls -BackColor $backgroundColor -ForeColor $foregroundColor -AccentColor $accentColor
}

# Function to apply theme to controls recursively
function Apply-ThemeToControls {
    param(
        [System.Windows.Forms.Control+ControlCollection]$Controls,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$ForeColor,
        [System.Drawing.Color]$AccentColor
    )
    
    foreach ($control in $Controls) {
        # Apply theme based on control type
        switch ($control.GetType().Name) {
            "Panel" {
                if ($control.BackColor -eq [System.Drawing.Color]::White -or $control.BackColor -eq [System.Drawing.Color]::FromArgb(240, 240, 240)) {
                    $control.BackColor = $BackColor
                }
                $control.ForeColor = $ForeColor
            }
            "Label" {
                $control.ForeColor = $ForeColor
            }
            "Button" {
                # Keep button-specific colors but adjust if needed
                if ($control.BackColor -eq [System.Drawing.SystemColors]::Control) {
                    $control.BackColor = $AccentColor
                    $control.ForeColor = [System.Drawing.Color]::White
                }
            }
            "TextBox" {
                $control.BackColor = [System.Drawing.Color]::White
                $control.ForeColor = [System.Drawing.Color]::Black
            }
            "RichTextBox" {
                # Keep console colors for log output
                if (-not ($control.BackColor -eq [System.Drawing.Color]::Black)) {
                    $control.BackColor = $BackColor
                    $control.ForeColor = $ForeColor
                }
            }
            "TreeView" {
                $control.BackColor = [System.Drawing.Color]::White
                $control.ForeColor = [System.Drawing.Color]::Black
            }
            "ListView" {
                $control.BackColor = [System.Drawing.Color]::White
                $control.ForeColor = [System.Drawing.Color]::Black
            }
        }
        
        # Recursively apply to child controls
        if ($control.Controls.Count -gt 0) {
            Apply-ThemeToControls -Controls $control.Controls -BackColor $BackColor -ForeColor $ForeColor -AccentColor $AccentColor
        }
    }
}

# Function to get script metadata
function Get-ScriptMetadata {
    param(
        [string]$ScriptPath
    )
    
    $metadata = @{
        DisplayName = ""
        Description = ""
        Category = ""
        RequiresRestart = $false
        RiskLevel = "Medium"
        EstimatedTime = "< 1 minute"
        Prerequisites = @()
        AffectedAreas = @()
    }
    
    if (Test-Path $ScriptPath) {
        try {
            $content = Get-Content $ScriptPath -TotalCount 30
            
            foreach ($line in $content) {
                $line = $line.Trim()
                
                # Parse metadata comments
                if ($line -match '^:: DisplayName: (.+)$') {
                    $metadata.DisplayName = $matches[1]
                }
                elseif ($line -match '^:: Description: (.+)$') {
                    $metadata.Description = $matches[1]
                }
                elseif ($line -match '^:: Category: (.+)$') {
                    $metadata.Category = $matches[1]
                }
                elseif ($line -match '^:: RequiresRestart: (true|false)$') {
                    $metadata.RequiresRestart = $matches[1] -eq "true"
                }
                elseif ($line -match '^:: RiskLevel: (Low|Medium|High)$') {
                    $metadata.RiskLevel = $matches[1]
                }
                elseif ($line -match '^:: EstimatedTime: (.+)$') {
                    $metadata.EstimatedTime = $matches[1]
                }
                elseif ($line -match '^:: Prerequisites: (.+)$') {
                    $metadata.Prerequisites = $matches[1] -split ','
                }
                elseif ($line -match '^:: AffectedAreas: (.+)$') {
                    $metadata.AffectedAreas = $matches[1] -split ','
                }
            }
        }
        catch {
            # Use defaults if unable to parse
        }
    }
    
    return $metadata
}

# Function to validate script compatibility
function Test-ScriptCompatibility {
    param(
        [string]$ScriptPath
    )
    
    $compatibility = @{
        IsCompatible = $true
        Warnings = @()
        Requirements = @()
    }
    
    if (-not (Test-Path $ScriptPath)) {
        $compatibility.IsCompatible = $false
        $compatibility.Warnings += "Script file not found"
        return $compatibility
    }
    
    # Check Windows version compatibility
    $osVersion = [System.Environment]::OSVersion.Version
    $windowsVersion = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty Caption
    
    # Check if script requires specific Windows features
    $scriptContent = Get-Content $ScriptPath -Raw
    
    if ($scriptContent -match "Get-AppxPackage" -and $osVersion.Major -lt 10) {
        $compatibility.Warnings += "This script requires Windows 10 or later for full functionality"
    }
    
    if ($scriptContent -match "dism.exe" -and -not (Get-Command "dism.exe" -ErrorAction SilentlyContinue)) {
        $compatibility.Warnings += "DISM tool is required but not available"
    }
    
    # Check PowerShell version requirements
    if ($scriptContent -match "Invoke-WebRequest" -and $PSVersionTable.PSVersion.Major -lt 3) {
        $compatibility.Requirements += "PowerShell 3.0 or later required for web requests"
    }
    
    return $compatibility
}

# Function to create enhanced tooltips
function Set-EnhancedTooltip {
    param(
        [System.Windows.Forms.Control]$Control,
        [string]$Text,
        [string]$Title = "",
        [int]$AutoPopDelay = 5000
    )
    
    $tooltip = New-Object System.Windows.Forms.ToolTip
    $tooltip.AutoPopDelay = $AutoPopDelay
    $tooltip.InitialDelay = 500
    $tooltip.ReshowDelay = 100
    $tooltip.ShowAlways = $true
    
    if ($Title -ne "") {
        $tooltip.ToolTipTitle = $Title
        $tooltip.ToolTipIcon = "Info"
    }
    
    $tooltip.SetToolTip($Control, $Text)
    
    return $tooltip
}

# Function to create progress dialog
function Show-ProgressDialog {
    param(
        [string]$Title = "Operation in Progress",
        [string]$Message = "Please wait...",
        [int]$Maximum = 100
    )
    
    $progressForm = New-Object System.Windows.Forms.Form
    $progressForm.Text = $Title
    $progressForm.Size = New-Object System.Drawing.Size(400, 150)
    $progressForm.StartPosition = "CenterParent"
    $progressForm.FormBorderStyle = "FixedDialog"
    $progressForm.MaximizeBox = $false
    $progressForm.MinimizeBox = $false
    $progressForm.ControlBox = $false
    
    $messageLabel = New-Object System.Windows.Forms.Label
    $messageLabel.Text = $Message
    $messageLabel.Location = New-Object System.Drawing.Point(20, 20)
    $messageLabel.Size = New-Object System.Drawing.Size(360, 30)
    $messageLabel.TextAlign = "MiddleCenter"
    
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(20, 60)
    $progressBar.Size = New-Object System.Drawing.Size(360, 25)
    $progressBar.Maximum = $Maximum
    $progressBar.Style = "Marquee"
    $progressBar.MarqueeAnimationSpeed = 30
    
    $progressForm.Controls.AddRange(@($messageLabel, $progressBar))
    
    return @{
        Form = $progressForm
        Label = $messageLabel
        ProgressBar = $progressBar
    }
}

# Export functions for use in main GUI
Export-ModuleMember -Function @(
    'Get-GUIConfiguration',
    'Set-GUITheme',
    'Get-ScriptMetadata',
    'Test-ScriptCompatibility',
    'Set-EnhancedTooltip',
    'Show-ProgressDialog'
)