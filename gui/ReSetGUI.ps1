# ReSet Toolkit - PowerShell GUI Application
# Interactive Windows Forms interface for the Windows Settings Reset Toolkit

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# Import configuration module with enhanced error handling
$ModulePath = Join-Path $PSScriptRoot "GUIConfig.psm1"
try {
    if (Test-Path $ModulePath) {
        Import-Module $ModulePath -Force -ErrorAction Stop
        Write-Verbose "Successfully loaded GUIConfig module"
    } else {
        Write-Warning "GUIConfig module not found at: $ModulePath"
    }
} catch {
    Write-Error "Failed to load GUIConfig module: $($_.Exception.Message)"
    # Continue with basic functionality
}

# Global variables
$script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:ResetRoot = Split-Path -Parent $script:ScriptRoot
$script:ScriptsPath = Join-Path $script:ResetRoot "scripts"
$script:LogsPath = Join-Path $script:ResetRoot "logs"
$script:BackupsPath = Join-Path $script:ResetRoot "backups"
$script:ConfigPath = Join-Path $script:ResetRoot "config.ini"
$script:GUIConfig = $null
$script:CurrentTheme = "Light"
$script:CachedScripts = $null
$script:LastScanTime = $null
$script:SelectedScript = $null
$script:IsProcessing = $false

# Load GUI configuration
try {
    $script:GUIConfig = Get-GUIConfiguration
    $script:CurrentTheme = $script:GUIConfig.UI.Theme
}
catch {
    Write-Warning "Could not load GUI configuration: $($_.Exception.Message)"
    $script:GUIConfig = @{
        UI = @{
            Theme = "Light"
            AutoRefresh = "true"
            ShowTooltips = "true"
            ConfirmActions = "true"
        }
    }
}

# Available scripts detection and categorization
$script:AvailableScripts = @{}
$script:ScriptCategories = @{
    "Language & Regional" = @("reset-language-settings", "reset-datetime")
    "Display & Audio" = @("reset-display", "reset-audio", "reset-fonts")
    "Network & Connectivity" = @("reset-network", "reset-windows-update", "reset-browser")
    "Security & Privacy" = @("reset-uac", "reset-privacy", "reset-defender")
    "Search & Interface" = @("reset-search", "reset-startmenu", "reset-shell")
    "File Management" = @("reset-file-associations", "reset-fonts")
    "Performance & Power" = @("reset-power", "reset-performance")
    "Applications & Store" = @("reset-browser", "reset-store")
    "Input & Accessibility" = @("reset-input-devices")
    "System Components" = @("reset-features", "reset-environment", "reset-registry")
}

# Override with configured category order if available
if ($script:GUIConfig -and $script:GUIConfig.Categories -and $script:GUIConfig.Categories.DisplayOrder) {
    $categoryOrder = $script:GUIConfig.Categories.DisplayOrder -split ','
    $newCategories = [ordered]@{}
    foreach ($cat in $categoryOrder) {
        $cat = $cat.Trim()
        if ($script:ScriptCategories.ContainsKey($cat)) {
            $newCategories[$cat] = $script:ScriptCategories[$cat]
        }
    }
    # Add any missing categories
    foreach ($cat in $script:ScriptCategories.Keys) {
        if (-not $newCategories.ContainsKey($cat)) {
            $newCategories[$cat] = $script:ScriptCategories[$cat]
        }
    }
    $script:ScriptCategories = $newCategories
}

# Function to scan for available scripts with caching and performance optimization
function Get-AvailableScripts {
    param(
        [switch]$Force,
        [switch]$ShowProgress
    )
    
    # Use cached results if available and not forcing refresh
    if (-not $Force -and $script:CachedScripts -and $script:LastScanTime -and 
        ((Get-Date) - $script:LastScanTime).TotalMinutes -lt 5) {
        return $script:CachedScripts
    }
    
    $scripts = @{}
    
    if (Test-Path $script:ScriptsPath) {
        $scriptFiles = Get-ChildItem -Path $script:ScriptsPath -Filter "reset-*.bat" -ErrorAction SilentlyContinue
        
        if ($ShowProgress -and $scriptFiles.Count -gt 0) {
            Write-Progress -Activity "Scanning Scripts" -Status "Found $($scriptFiles.Count) script files" -PercentComplete 0
        }
        
        $processedCount = 0
        foreach ($file in $scriptFiles) {
            if ($ShowProgress) {
                $percentComplete = [math]::Round(($processedCount / $scriptFiles.Count) * 100)
                Write-Progress -Activity "Scanning Scripts" -Status "Processing: $($file.Name)" -PercentComplete $percentComplete
            }
            
            $scriptName = $file.BaseName
            $displayName = ($scriptName -replace "reset-", "" -replace "-", " ")
            $displayName = (Get-Culture).TextInfo.ToTitleCase($displayName.ToLower())
            
            $processedCount++
            
            # Get enhanced metadata if configuration module is available
            $metadata = $null
            try {
                if (Get-Command "Get-ScriptMetadata" -ErrorAction SilentlyContinue) {
                    $metadata = Get-ScriptMetadata -ScriptPath $file.FullName
                    if ($metadata.DisplayName) {
                        $displayName = $metadata.DisplayName
                    }
                }
            }
            catch {
                # Use default parsing if metadata function fails
            }
            
            # Read script description from file
            $description = "Windows settings reset script"
            $riskLevel = "Medium"
            $requiresRestart = $false
            
            try {
                $content = Get-Content $file.FullName -TotalCount 15
                foreach ($line in $content) {
                    if ($line -match "^:: (.+)$") {
                        $comment = $matches[1].Trim()
                        if ($comment -match "^Description: (.+)$") {
                            $description = $matches[1]
                        }
                        elseif ($comment -match "^RiskLevel: (Low|Medium|High)$") {
                            $riskLevel = $matches[1]
                        }
                        elseif ($comment -match "^RequiresRestart: (true|false)$") {
                            $requiresRestart = $matches[1] -eq "true"
                        }
                    }
                    elseif ($line -match "::" -and $line -match "Reset" -and $description -eq "Windows settings reset script") {
                        $description = ($line -replace "::", "").Trim()
                    }
                }
            }
            catch {
                # Use default description if unable to read file
            }
            
            $scripts[$scriptName] = @{
                DisplayName = $displayName
                Description = $description
                FilePath = $file.FullName
                Category = Get-ScriptCategory $scriptName
                LastModified = $file.LastWriteTime
                RiskLevel = $riskLevel
                RequiresRestart = $requiresRestart
                Metadata = $metadata
                FileSize = $file.Length
                IsReadOnly = $file.IsReadOnly
            }
        }
        
        if ($ShowProgress) {
            Write-Progress -Activity "Scanning Scripts" -Completed
        }
    } else {
        Write-Warning "Scripts directory not found: $script:ScriptsPath"
    }
    
    # Cache the results
    $script:CachedScripts = $scripts
    $script:LastScanTime = Get-Date
    
    return $scripts
}

# Function to determine script category
function Get-ScriptCategory {
    param($scriptName)
    
    foreach ($category in $script:ScriptCategories.Keys) {
        if ($script:ScriptCategories[$category] -contains $scriptName) {
            return $category
        }
    }
    return "Other"
}

# Function to filter tree view based on search text
function Filter-TreeView {
    param(
        [string]$SearchText,
        [System.Windows.Forms.TreeView]$TreeView
    )
    
    if ([string]::IsNullOrWhiteSpace($SearchText)) {
        # Show all nodes
        foreach ($categoryNode in $TreeView.Nodes) {
            $categoryNode.Collapse()
            foreach ($scriptNode in $categoryNode.Nodes) {
                $scriptNode.BackColor = [System.Drawing.Color]::White
                $scriptNode.ForeColor = [System.Drawing.Color]::Black
            }
            $categoryNode.Expand()
        }
        return
    }
    
    # Filter nodes based on search text
    foreach ($categoryNode in $TreeView.Nodes) {
        $hasVisibleChildren = $false
        foreach ($scriptNode in $categoryNode.Nodes) {
            if ($scriptNode.Text -like "*$SearchText*" -or 
                $scriptNode.Tag.Info.Description -like "*$SearchText*") {
                $scriptNode.BackColor = [System.Drawing.Color]::Yellow
                $scriptNode.ForeColor = [System.Drawing.Color]::Black
                $hasVisibleChildren = $true
            } else {
                $scriptNode.BackColor = [System.Drawing.Color]::LightGray
                $scriptNode.ForeColor = [System.Drawing.Color]::Gray
            }
        }
        
        if ($hasVisibleChildren) {
            $categoryNode.Expand()
        } else {
            $categoryNode.Collapse()
        }
    }
}

# Function to refresh scripts with UI updates
function Refresh-Scripts {
    if ($script:IsProcessing) {
        return
    }
    
    $script:IsProcessing = $true
    try {
        Add-LogEntry "Refreshing script list..." "INFO"
        $script:StatusLabel.Text = "Refreshing..."
        
        # Clear cached data
        $script:CachedScripts = $null
        $script:LastScanTime = $null
        
        # Rescan scripts
        $script:AvailableScripts = Get-AvailableScripts -Force -ShowProgress
        
        # Update script count
        $script:ScriptCountLabel.Text = "Scripts: $($script:AvailableScripts.Count)"
        
        # Refresh tree view (this would need to be called from the main event handler)
        Add-LogEntry "Script list refreshed - Found $($script:AvailableScripts.Count) scripts" "SUCCESS"
        $script:StatusLabel.Text = "Ready"
    }
    catch {
        Add-LogEntry "Error refreshing scripts: $($_.Exception.Message)" "ERROR"
        $script:StatusLabel.Text = "Error"
    }
    finally {
        $script:IsProcessing = $false
    }
}

# Function to create the main form with enhanced features
function New-MainForm {
    # Get window size from configuration with validation
    $width = 1200
    $height = 800
    try {
        if ($script:GUIConfig.UI.WindowWidth -and [int]$script:GUIConfig.UI.WindowWidth -ge 1000) {
            $width = [int]$script:GUIConfig.UI.WindowWidth
        }
        if ($script:GUIConfig.UI.WindowHeight -and [int]$script:GUIConfig.UI.WindowHeight -ge 700) {
            $height = [int]$script:GUIConfig.UI.WindowHeight
        }
    } catch {
        Write-Warning "Invalid window size in configuration, using defaults"
    }
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "ReSet Toolkit - Windows Settings Reset GUI v2.1 Enhanced"
    $form.Size = New-Object System.Drawing.Size($width, $height)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "Sizable"
    $form.MaximizeBox = $true
    $form.MinimumSize = New-Object System.Drawing.Size(1000, 700)
    $form.Icon = [System.Drawing.SystemIcons]::WinLogo
    $form.KeyPreview = $true  # Enable keyboard shortcuts
    $form.DoubleBuffered = $true  # Reduce flicker
    
    # Set colors and styling based on theme
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Apply theme if module is available
    try {
        if (Get-Command "Set-GUITheme" -ErrorAction SilentlyContinue) {
            Set-GUITheme -Theme $script:CurrentTheme -Form $form
        }
    }
    catch {
        Write-Warning "Could not apply theme: $($_.Exception.Message)"
    }
    
    # Add keyboard shortcuts
    $form.add_KeyDown({
        param($sender, $e)
        switch ($e.KeyCode) {
            "F1" { Show-Help }
            "F5" { Refresh-Scripts }
            "Escape" { 
                if (-not $script:IsProcessing) {
                    $form.Close()
                }
            }
            "F11" {
                if ($form.WindowState -eq "Normal") {
                    $form.WindowState = "Maximized"
                } else {
                    $form.WindowState = "Normal"
                }
            }
        }
        if ($e.Control) {
            switch ($e.KeyCode) {
                "Q" { $form.Close() }
                "R" { Refresh-Scripts }
                "H" { Show-Help }
            }
        }
    })
    
    return $form
}

# Function to create header panel
function New-HeaderPanel {
    param($form)
    
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Size = New-Object System.Drawing.Size(1180, 80)
    $headerPanel.Location = New-Object System.Drawing.Point(10, 10)
    $headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    
    # Title label
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Windows Settings Reset Toolkit"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::White
    $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
    $titleLabel.AutoSize = $true
    
    # Subtitle label
    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Text = "Professional Windows Configuration Reset Tool"
    $subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $subtitleLabel.Location = New-Object System.Drawing.Point(20, 45)
    $subtitleLabel.AutoSize = $true
    
    # Status label with enhanced information
    $script:StatusLabel = New-Object System.Windows.Forms.Label
    $script:StatusLabel.Text = "Ready"
    $script:StatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $script:StatusLabel.ForeColor = [System.Drawing.Color]::White
    $script:StatusLabel.Location = New-Object System.Drawing.Point(750, 15)
    $script:StatusLabel.Size = New-Object System.Drawing.Size(200, 20)
    $script:StatusLabel.TextAlign = "MiddleRight"
    
    # Script count label
    $script:ScriptCountLabel = New-Object System.Windows.Forms.Label
    $script:ScriptCountLabel.Text = "Scripts: 0"
    $script:ScriptCountLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $script:ScriptCountLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $script:ScriptCountLabel.Location = New-Object System.Drawing.Point(750, 35)
    $script:ScriptCountLabel.Size = New-Object System.Drawing.Size(100, 15)
    $script:ScriptCountLabel.TextAlign = "MiddleRight"
    
    # Version label
    $script:VersionLabel = New-Object System.Windows.Forms.Label
    $script:VersionLabel.Text = "v2.1 Enhanced"
    $script:VersionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $script:VersionLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $script:VersionLabel.Location = New-Object System.Drawing.Point(750, 50)
    $script:VersionLabel.Size = New-Object System.Drawing.Size(100, 15)
    $script:VersionLabel.TextAlign = "MiddleRight"
    
    $headerPanel.Controls.AddRange(@($titleLabel, $subtitleLabel, $script:StatusLabel, $script:ScriptCountLabel, $script:VersionLabel))
    $form.Controls.Add($headerPanel)
    
    return $headerPanel
}

# Function to create script categories tree view
function New-ScriptTreeView {
    param($form)
    
    $treeView = New-Object System.Windows.Forms.TreeView
    $treeView.Size = New-Object System.Drawing.Size(350, 500)
    $treeView.Location = New-Object System.Drawing.Point(20, 110)
    $treeView.BackColor = [System.Drawing.Color]::White
    $treeView.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $treeView.HideSelection = $false
    $treeView.FullRowSelect = $true
    $treeView.ShowLines = $true
    $treeView.ShowPlusMinus = $true
    $treeView.ShowRootLines = $true
    
    # Add search box above tree view
    $searchLabel = New-Object System.Windows.Forms.Label
    $searchLabel.Text = "Search:"
    $searchLabel.Location = New-Object System.Drawing.Point(20, 85)
    $searchLabel.Size = New-Object System.Drawing.Size(50, 20)
    $searchLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $script:SearchBox = New-Object System.Windows.Forms.TextBox
    $script:SearchBox.Location = New-Object System.Drawing.Point(75, 85)
    $script:SearchBox.Size = New-Object System.Drawing.Size(200, 20)
    $script:SearchBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Clear search button
    $script:ClearSearchButton = New-Object System.Windows.Forms.Button
    $script:ClearSearchButton.Text = "×"
    $script:ClearSearchButton.Size = New-Object System.Drawing.Size(20, 20)
    $script:ClearSearchButton.Location = New-Object System.Drawing.Point(280, 85)
    $script:ClearSearchButton.FlatStyle = "Flat"
    $script:ClearSearchButton.BackColor = [System.Drawing.Color]::LightGray
    
    $form.Controls.AddRange(@($searchLabel, $script:SearchBox, $script:ClearSearchButton))
    
    # Populate tree with scripts using enhanced function
    $script:AvailableScripts = Get-AvailableScripts -ShowProgress
    
    # Update script count
    $script:ScriptCountLabel.Text = "Scripts: $($script:AvailableScripts.Count)"
    
    foreach ($category in $script:ScriptCategories.Keys) {
        $categoryNode = New-Object System.Windows.Forms.TreeNode($category)
        $categoryNode.Tag = @{ Type = "Category"; Name = $category }
        $categoryNode.NodeFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        
        $scriptsInCategory = $script:ScriptCategories[$category]
        foreach ($scriptName in $scriptsInCategory) {
            if ($script:AvailableScripts.ContainsKey($scriptName)) {
                $scriptInfo = $script:AvailableScripts[$scriptName]
                $scriptNode = New-Object System.Windows.Forms.TreeNode($scriptInfo.DisplayName)
                $scriptNode.Tag = @{ 
                    Type = "Script"
                    Name = $scriptName
                    Info = $scriptInfo
                }
                $categoryNode.Nodes.Add($scriptNode)
            }
        }
        
        if ($categoryNode.Nodes.Count -gt 0) {
            $treeView.Nodes.Add($categoryNode)
        }
    }
    
    # Expand all categories
    $treeView.ExpandAll()
    
    # Add search functionality
    $script:SearchBox.add_TextChanged({
        Filter-TreeView -SearchText $script:SearchBox.Text -TreeView $treeView
    })
    
    $script:ClearSearchButton.add_Click({
        $script:SearchBox.Text = ""
        $treeView.CollapseAll()
        $treeView.ExpandAll()
    })
    
    $form.Controls.Add($treeView)
    return $treeView
}

# Function to create script details panel
function New-DetailsPanel {
    param($form)
    
    $detailsPanel = New-Object System.Windows.Forms.Panel
    $detailsPanel.Size = New-Object System.Drawing.Size(400, 350)
    $detailsPanel.Location = New-Object System.Drawing.Point(390, 110)
    $detailsPanel.BackColor = [System.Drawing.Color]::White
    $detailsPanel.BorderStyle = "FixedSingle"
    $detailsPanel.Anchor = "Top,Left,Right"
    
    # Script name label
    $script:ScriptNameLabel = New-Object System.Windows.Forms.Label
    $script:ScriptNameLabel.Text = "Select a script to view details"
    $script:ScriptNameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $script:ScriptNameLabel.Location = New-Object System.Drawing.Point(15, 15)
    $script:ScriptNameLabel.Size = New-Object System.Drawing.Size(370, 25)
    
    # Risk level indicator
    $script:RiskLevelLabel = New-Object System.Windows.Forms.Label
    $script:RiskLevelLabel.Text = ""
    $script:RiskLevelLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $script:RiskLevelLabel.Location = New-Object System.Drawing.Point(15, 45)
    $script:RiskLevelLabel.Size = New-Object System.Drawing.Size(100, 20)
    $script:RiskLevelLabel.TextAlign = "MiddleCenter"
    $script:RiskLevelLabel.BackColor = [System.Drawing.Color]::LightGray
    
    # Restart required indicator
    $script:RestartLabel = New-Object System.Windows.Forms.Label
    $script:RestartLabel.Text = ""
    $script:RestartLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $script:RestartLabel.Location = New-Object System.Drawing.Point(125, 45)
    $script:RestartLabel.Size = New-Object System.Drawing.Size(120, 20)
    $script:RestartLabel.TextAlign = "MiddleCenter"
    $script:RestartLabel.BackColor = [System.Drawing.Color]::Orange
    $script:RestartLabel.ForeColor = [System.Drawing.Color]::White
    $script:RestartLabel.Visible = $false
    
    # Script description
    $script:ScriptDescriptionLabel = New-Object System.Windows.Forms.Label
    $script:ScriptDescriptionLabel.Text = ""
    $script:ScriptDescriptionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $script:ScriptDescriptionLabel.Location = New-Object System.Drawing.Point(15, 75)
    $script:ScriptDescriptionLabel.Size = New-Object System.Drawing.Size(370, 80)
    
    # Script details group
    $detailsGroup = New-Object System.Windows.Forms.GroupBox
    $detailsGroup.Text = "Script Information"
    $detailsGroup.Location = New-Object System.Drawing.Point(15, 165)
    $detailsGroup.Size = New-Object System.Drawing.Size(370, 90)
    $detailsGroup.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    
    # Script path
    $script:ScriptPathLabel = New-Object System.Windows.Forms.Label
    $script:ScriptPathLabel.Text = ""
    $script:ScriptPathLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
    $script:ScriptPathLabel.ForeColor = [System.Drawing.Color]::Gray
    $script:ScriptPathLabel.Location = New-Object System.Drawing.Point(10, 20)
    $script:ScriptPathLabel.Size = New-Object System.Drawing.Size(350, 20)
    
    # Last modified
    $script:LastModifiedLabel = New-Object System.Windows.Forms.Label
    $script:LastModifiedLabel.Text = ""
    $script:LastModifiedLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $script:LastModifiedLabel.ForeColor = [System.Drawing.Color]::Gray
    $script:LastModifiedLabel.Location = New-Object System.Drawing.Point(10, 45)
    $script:LastModifiedLabel.Size = New-Object System.Drawing.Size(350, 20)
    
    # Compatibility status
    $script:CompatibilityLabel = New-Object System.Windows.Forms.Label
    $script:CompatibilityLabel.Text = ""
    $script:CompatibilityLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $script:CompatibilityLabel.Location = New-Object System.Drawing.Point(10, 65)
    $script:CompatibilityLabel.Size = New-Object System.Drawing.Size(350, 20)
    
    $detailsGroup.Controls.AddRange(@(
        $script:ScriptPathLabel,
        $script:LastModifiedLabel,
        $script:CompatibilityLabel
    ))
    
    # Action buttons
    $script:RunSingleButton = New-Object System.Windows.Forms.Button
    $script:RunSingleButton.Text = "▶ Run This Script"
    $script:RunSingleButton.Size = New-Object System.Drawing.Size(120, 40)
    $script:RunSingleButton.Location = New-Object System.Drawing.Point(15, 270)
    $script:RunSingleButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $script:RunSingleButton.ForeColor = [System.Drawing.Color]::White
    $script:RunSingleButton.FlatStyle = "Flat"
    $script:RunSingleButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $script:RunSingleButton.Enabled = $false
    
    $script:ViewScriptButton = New-Object System.Windows.Forms.Button
    $script:ViewScriptButton.Text = "👁 View Script"
    $script:ViewScriptButton.Size = New-Object System.Drawing.Size(100, 40)
    $script:ViewScriptButton.Location = New-Object System.Drawing.Point(145, 270)
    $script:ViewScriptButton.BackColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
    $script:ViewScriptButton.ForeColor = [System.Drawing.Color]::White
    $script:ViewScriptButton.FlatStyle = "Flat"
    $script:ViewScriptButton.Enabled = $false
    
    $script:BackupInfoButton = New-Object System.Windows.Forms.Button
    $script:BackupInfoButton.Text = "💾 Backup Info"
    $script:BackupInfoButton.Size = New-Object System.Drawing.Size(100, 40)
    $script:BackupInfoButton.Location = New-Object System.Drawing.Point(255, 270)
    $script:BackupInfoButton.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
    $script:BackupInfoButton.ForeColor = [System.Drawing.Color]::White
    $script:BackupInfoButton.FlatStyle = "Flat"
    $script:BackupInfoButton.Enabled = $false
    
    # Preview/Test button
    $script:PreviewButton = New-Object System.Windows.Forms.Button
    $script:PreviewButton.Text = "🔍 Preview Changes"
    $script:PreviewButton.Size = New-Object System.Drawing.Size(120, 25)
    $script:PreviewButton.Location = New-Object System.Drawing.Point(15, 320)
    $script:PreviewButton.BackColor = [System.Drawing.Color]::FromArgb(255, 193, 7)
    $script:PreviewButton.ForeColor = [System.Drawing.Color]::Black
    $script:PreviewButton.FlatStyle = "Flat"
    $script:PreviewButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $script:PreviewButton.Enabled = $false
    
    # Add tooltips if enabled
    if ($script:GUIConfig.UI.ShowTooltips -eq "true") {
        try {
            if (Get-Command "Set-EnhancedTooltip" -ErrorAction SilentlyContinue) {
                Set-EnhancedTooltip -Control $script:RunSingleButton -Text "Execute the selected reset script with confirmation prompts" -Title "Run Script"
                Set-EnhancedTooltip -Control $script:ViewScriptButton -Text "Open the script file in the default text editor for review" -Title "View Script"
                Set-EnhancedTooltip -Control $script:BackupInfoButton -Text "View information about backups created by this script" -Title "Backup Information"
                Set-EnhancedTooltip -Control $script:PreviewButton -Text "Preview what changes this script will make without executing" -Title "Preview Mode"
            }
        }
        catch {
            # Continue without tooltips if module unavailable
        }
    }
    
    $detailsPanel.Controls.AddRange(@(
        $script:ScriptNameLabel,
        $script:RiskLevelLabel,
        $script:RestartLabel,
        $script:ScriptDescriptionLabel,
        $detailsGroup,
        $script:RunSingleButton,
        $script:ViewScriptButton,
        $script:BackupInfoButton,
        $script:PreviewButton
    ))
    
    $form.Controls.Add($detailsPanel)
    return $detailsPanel
}

# Function to create batch operations panel
function New-BatchPanel {
    param($form)
    
    $batchPanel = New-Object System.Windows.Forms.GroupBox
    $batchPanel.Text = "Batch Operations"
    $batchPanel.Size = New-Object System.Drawing.Size(400, 200)
    $batchPanel.Location = New-Object System.Drawing.Point(390, 430)
    $batchPanel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    
    # Category selection
    $categoryLabel = New-Object System.Windows.Forms.Label
    $categoryLabel.Text = "Select Categories:"
    $categoryLabel.Location = New-Object System.Drawing.Point(15, 30)
    $categoryLabel.Size = New-Object System.Drawing.Size(120, 20)
    $categoryLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $script:CategoryCheckedListBox = New-Object System.Windows.Forms.CheckedListBox
    $script:CategoryCheckedListBox.Location = New-Object System.Drawing.Point(15, 55)
    $script:CategoryCheckedListBox.Size = New-Object System.Drawing.Size(180, 100)
    $script:CategoryCheckedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    
    # Populate categories
    foreach ($category in $script:ScriptCategories.Keys) {
        $script:CategoryCheckedListBox.Items.Add($category)
    }
    
    # Batch options
    $optionsLabel = New-Object System.Windows.Forms.Label
    $optionsLabel.Text = "Options:"
    $optionsLabel.Location = New-Object System.Drawing.Point(210, 30)
    $optionsLabel.Size = New-Object System.Drawing.Size(100, 20)
    $optionsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $script:CreateRestorePointCheckBox = New-Object System.Windows.Forms.CheckBox
    $script:CreateRestorePointCheckBox.Text = "Create Restore Point"
    $script:CreateRestorePointCheckBox.Location = New-Object System.Drawing.Point(210, 55)
    $script:CreateRestorePointCheckBox.Size = New-Object System.Drawing.Size(150, 20)
    $script:CreateRestorePointCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $script:CreateRestorePointCheckBox.Checked = $true
    
    $script:SilentModeCheckBox = New-Object System.Windows.Forms.CheckBox
    $script:SilentModeCheckBox.Text = "Silent Mode"
    $script:SilentModeCheckBox.Location = New-Object System.Drawing.Point(210, 80)
    $script:SilentModeCheckBox.Size = New-Object System.Drawing.Size(100, 20)
    $script:SilentModeCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    
    $script:VerifyBackupsCheckBox = New-Object System.Windows.Forms.CheckBox
    $script:VerifyBackupsCheckBox.Text = "Verify Backups"
    $script:VerifyBackupsCheckBox.Location = New-Object System.Drawing.Point(210, 105)
    $script:VerifyBackupsCheckBox.Size = New-Object System.Drawing.Size(120, 20)
    $script:VerifyBackupsCheckBox.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $script:VerifyBackupsCheckBox.Checked = $true
    
    # Batch action buttons
    $script:RunBatchButton = New-Object System.Windows.Forms.Button
    $script:RunBatchButton.Text = "Run Selected Categories"
    $script:RunBatchButton.Size = New-Object System.Drawing.Size(160, 35)
    $script:RunBatchButton.Location = New-Object System.Drawing.Point(15, 160)
    $script:RunBatchButton.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
    $script:RunBatchButton.ForeColor = [System.Drawing.Color]::White
    $script:RunBatchButton.FlatStyle = "Flat"
    $script:RunBatchButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    
    $script:SelectAllButton = New-Object System.Windows.Forms.Button
    $script:SelectAllButton.Text = "Select All"
    $script:SelectAllButton.Size = New-Object System.Drawing.Size(80, 25)
    $script:SelectAllButton.Location = New-Object System.Drawing.Point(190, 160)
    $script:SelectAllButton.BackColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
    $script:SelectAllButton.ForeColor = [System.Drawing.Color]::White
    $script:SelectAllButton.FlatStyle = "Flat"
    $script:SelectAllButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    
    $script:ClearAllButton = New-Object System.Windows.Forms.Button
    $script:ClearAllButton.Text = "Clear All"
    $script:ClearAllButton.Size = New-Object System.Drawing.Size(80, 25)
    $script:ClearAllButton.Location = New-Object System.Drawing.Point(280, 160)
    $script:ClearAllButton.BackColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
    $script:ClearAllButton.ForeColor = [System.Drawing.Color]::White
    $script:ClearAllButton.FlatStyle = "Flat"
    $script:ClearAllButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    
    $batchPanel.Controls.AddRange(@(
        $categoryLabel,
        $script:CategoryCheckedListBox,
        $optionsLabel,
        $script:CreateRestorePointCheckBox,
        $script:SilentModeCheckBox,
        $script:VerifyBackupsCheckBox,
        $script:RunBatchButton,
        $script:SelectAllButton,
        $script:ClearAllButton
    ))
    
    $form.Controls.Add($batchPanel)
    return $batchPanel
}

# Function to create system tools panel
function New-SystemToolsPanel {
    param($form)
    
    $toolsPanel = New-Object System.Windows.Forms.GroupBox
    $toolsPanel.Text = "System Tools"
    $toolsPanel.Size = New-Object System.Drawing.Size(350, 200)
    $toolsPanel.Location = New-Object System.Drawing.Point(810, 110)
    $toolsPanel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    
    # Health Check
    $script:HealthCheckButton = New-Object System.Windows.Forms.Button
    $script:HealthCheckButton.Text = "🏥 System Health Check"
    $script:HealthCheckButton.Size = New-Object System.Drawing.Size(160, 35)
    $script:HealthCheckButton.Location = New-Object System.Drawing.Point(15, 30)
    $script:HealthCheckButton.BackColor = [System.Drawing.Color]::FromArgb(25, 135, 84)
    $script:HealthCheckButton.ForeColor = [System.Drawing.Color]::White
    $script:HealthCheckButton.FlatStyle = "Flat"
    $script:HealthCheckButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Validation
    $script:ValidateButton = New-Object System.Windows.Forms.Button
    $script:ValidateButton.Text = "✅ Validate Installation"
    $script:ValidateButton.Size = New-Object System.Drawing.Size(160, 35)
    $script:ValidateButton.Location = New-Object System.Drawing.Point(185, 30)
    $script:ValidateButton.BackColor = [System.Drawing.Color]::FromArgb(13, 110, 253)
    $script:ValidateButton.ForeColor = [System.Drawing.Color]::White
    $script:ValidateButton.FlatStyle = "Flat"
    $script:ValidateButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Cleanup
    $script:CleanupButton = New-Object System.Windows.Forms.Button
    $script:CleanupButton.Text = "🧹 System Cleanup"
    $script:CleanupButton.Size = New-Object System.Drawing.Size(160, 35)
    $script:CleanupButton.Location = New-Object System.Drawing.Point(15, 80)
    $script:CleanupButton.BackColor = [System.Drawing.Color]::FromArgb(255, 193, 7)
    $script:CleanupButton.ForeColor = [System.Drawing.Color]::Black
    $script:CleanupButton.FlatStyle = "Flat"
    $script:CleanupButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Backup Manager
    $script:BackupManagerButton = New-Object System.Windows.Forms.Button
    $script:BackupManagerButton.Text = "💾 Backup Manager"
    $script:BackupManagerButton.Size = New-Object System.Drawing.Size(160, 35)
    $script:BackupManagerButton.Location = New-Object System.Drawing.Point(185, 80)
    $script:BackupManagerButton.BackColor = [System.Drawing.Color]::FromArgb(111, 66, 193)
    $script:BackupManagerButton.ForeColor = [System.Drawing.Color]::White
    $script:BackupManagerButton.FlatStyle = "Flat"
    $script:BackupManagerButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Configuration
    $script:ConfigButton = New-Object System.Windows.Forms.Button
    $script:ConfigButton.Text = "⚙️ Configuration"
    $script:ConfigButton.Size = New-Object System.Drawing.Size(160, 35)
    $script:ConfigButton.Location = New-Object System.Drawing.Point(15, 130)
    $script:ConfigButton.BackColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
    $script:ConfigButton.ForeColor = [System.Drawing.Color]::White
    $script:ConfigButton.FlatStyle = "Flat"
    $script:ConfigButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Logs Viewer
    $script:LogsButton = New-Object System.Windows.Forms.Button
    $script:LogsButton.Text = "📋 View Logs"
    $script:LogsButton.Size = New-Object System.Drawing.Size(160, 35)
    $script:LogsButton.Location = New-Object System.Drawing.Point(185, 130)
    $script:LogsButton.BackColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
    $script:LogsButton.ForeColor = [System.Drawing.Color]::White
    $script:LogsButton.FlatStyle = "Flat"
    $script:LogsButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $toolsPanel.Controls.AddRange(@(
        $script:HealthCheckButton,
        $script:ValidateButton,
        $script:CleanupButton,
        $script:BackupManagerButton,
        $script:ConfigButton,
        $script:LogsButton
    ))
    
    $form.Controls.Add($toolsPanel)
    return $toolsPanel
}

# Function to create progress panel
function New-ProgressPanel {
    param($form)
    
    $progressPanel = New-Object System.Windows.Forms.Panel
    $progressPanel.Size = New-Object System.Drawing.Size(350, 120)
    $progressPanel.Location = New-Object System.Drawing.Point(810, 330)
    $progressPanel.BackColor = [System.Drawing.Color]::White
    $progressPanel.BorderStyle = "FixedSingle"
    
    # Progress label
    $script:ProgressLabel = New-Object System.Windows.Forms.Label
    $script:ProgressLabel.Text = "Ready to start operations"
    $script:ProgressLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $script:ProgressLabel.Location = New-Object System.Drawing.Point(10, 10)
    $script:ProgressLabel.Size = New-Object System.Drawing.Size(330, 20)
    
    # Progress bar
    $script:ProgressBar = New-Object System.Windows.Forms.ProgressBar
    $script:ProgressBar.Location = New-Object System.Drawing.Point(10, 40)
    $script:ProgressBar.Size = New-Object System.Drawing.Size(330, 25)
    $script:ProgressBar.Style = "Continuous"
    
    # Current operation label
    $script:CurrentOperationLabel = New-Object System.Windows.Forms.Label
    $script:CurrentOperationLabel.Text = ""
    $script:CurrentOperationLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $script:CurrentOperationLabel.ForeColor = [System.Drawing.Color]::Gray
    $script:CurrentOperationLabel.Location = New-Object System.Drawing.Point(10, 75)
    $script:CurrentOperationLabel.Size = New-Object System.Drawing.Size(330, 35)
    
    $progressPanel.Controls.AddRange(@(
        $script:ProgressLabel,
        $script:ProgressBar,
        $script:CurrentOperationLabel
    ))
    
    $form.Controls.Add($progressPanel)
    return $progressPanel
}

# Function to create log output panel
function New-LogPanel {
    param($form)
    
    $logPanel = New-Object System.Windows.Forms.GroupBox
    $logPanel.Text = "Operation Log"
    $logPanel.Size = New-Object System.Drawing.Size(750, 120)
    $logPanel.Location = New-Object System.Drawing.Point(20, 640)
    $logPanel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    
    # Log text box
    $script:LogTextBox = New-Object System.Windows.Forms.RichTextBox
    $script:LogTextBox.Location = New-Object System.Drawing.Point(10, 25)
    $script:LogTextBox.Size = New-Object System.Drawing.Size(730, 85)
    $script:LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    $script:LogTextBox.ReadOnly = $true
    $script:LogTextBox.BackColor = [System.Drawing.Color]::Black
    $script:LogTextBox.ForeColor = [System.Drawing.Color]::White
    $script:LogTextBox.ScrollBars = "Vertical"
    
    $logPanel.Controls.Add($script:LogTextBox)
    $form.Controls.Add($logPanel)
    
    return $logPanel
}

# Function to create control buttons
function New-ControlButtons {
    param($form)
    
    # Refresh button
    $script:RefreshButton = New-Object System.Windows.Forms.Button
    $script:RefreshButton.Text = "🔄 Refresh Scripts"
    $script:RefreshButton.Size = New-Object System.Drawing.Size(120, 35)
    $script:RefreshButton.Location = New-Object System.Drawing.Point(810, 470)
    $script:RefreshButton.BackColor = [System.Drawing.Color]::FromArgb(23, 162, 184)
    $script:RefreshButton.ForeColor = [System.Drawing.Color]::White
    $script:RefreshButton.FlatStyle = "Flat"
    $script:RefreshButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Export button
    $script:ExportButton = New-Object System.Windows.Forms.Button
    $script:ExportButton.Text = "📊 Export Report"
    $script:ExportButton.Size = New-Object System.Drawing.Size(120, 35)
    $script:ExportButton.Location = New-Object System.Drawing.Point(810, 515)
    $script:ExportButton.BackColor = [System.Drawing.Color]::FromArgb(111, 66, 193)
    $script:ExportButton.ForeColor = [System.Drawing.Color]::White
    $script:ExportButton.FlatStyle = "Flat"
    $script:ExportButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Statistics button
    $script:StatsButton = New-Object System.Windows.Forms.Button
    $script:StatsButton.Text = "📈 Statistics"
    $script:StatsButton.Size = New-Object System.Drawing.Size(100, 35)
    $script:StatsButton.Location = New-Object System.Drawing.Point(940, 515)
    $script:StatsButton.BackColor = [System.Drawing.Color]::FromArgb(255, 140, 0)
    $script:StatsButton.ForeColor = [System.Drawing.Color]::White
    $script:StatsButton.FlatStyle = "Flat"
    $script:StatsButton.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    
    # Help button
    $script:HelpButton = New-Object System.Windows.Forms.Button
    $script:HelpButton.Text = "❓ Help"
    $script:HelpButton.Size = New-Object System.Drawing.Size(80, 35)
    $script:HelpButton.Location = New-Object System.Drawing.Point(940, 470)
    $script:HelpButton.BackColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
    $script:HelpButton.ForeColor = [System.Drawing.Color]::White
    $script:HelpButton.FlatStyle = "Flat"
    $script:HelpButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    # Exit button
    $script:ExitButton = New-Object System.Windows.Forms.Button
    $script:ExitButton.Text = "❌ Exit"
    $script:ExitButton.Size = New-Object System.Drawing.Size(80, 35)
    $script:ExitButton.Location = New-Object System.Drawing.Point(1030, 470)
    $script:ExitButton.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
    $script:ExitButton.ForeColor = [System.Drawing.Color]::White
    $script:ExitButton.FlatStyle = "Flat"
    $script:ExitButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    
    $form.Controls.AddRange(@(
        $script:RefreshButton,
        $script:ExportButton,
        $script:StatsButton,
        $script:HelpButton,
        $script:ExitButton
    ))
}

# Function to add log entry
function Add-LogEntry {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message`r`n"
    
    $script:LogTextBox.AppendText($logEntry)
    $script:LogTextBox.ScrollToCaret()
    
    # Update status
    $script:StatusLabel.Text = $Message
    
    # Refresh the form
    $script:MainForm.Refresh()
}

# Function to update progress
function Update-Progress {
    param(
        [int]$Percentage,
        [string]$Operation
    )
    
    $script:ProgressBar.Value = $Percentage
    $script:ProgressLabel.Text = "Progress: $Percentage%"
    $script:CurrentOperationLabel.Text = $Operation
    
    $script:MainForm.Refresh()
}

# Event handlers
function Register-EventHandlers {
    param($form, $treeView)
    
    # Tree view selection changed
    $treeView.add_AfterSelect({
        $selectedNode = $args[0].Node
        
        if ($selectedNode.Tag.Type -eq "Script") {
            $scriptInfo = $selectedNode.Tag.Info
            
            # Update script information
            $script:ScriptNameLabel.Text = $scriptInfo.DisplayName
            $script:ScriptDescriptionLabel.Text = $scriptInfo.Description
            $script:ScriptPathLabel.Text = "Path: " + $scriptInfo.FilePath
            $script:LastModifiedLabel.Text = "Modified: " + $scriptInfo.LastModified.ToString("yyyy-MM-dd HH:mm:ss")
            
            # Update risk level indicator
            $script:RiskLevelLabel.Text = "Risk: " + $scriptInfo.RiskLevel
            switch ($scriptInfo.RiskLevel) {
                "Low" { 
                    $script:RiskLevelLabel.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
                    $script:RiskLevelLabel.ForeColor = [System.Drawing.Color]::White
                }
                "Medium" { 
                    $script:RiskLevelLabel.BackColor = [System.Drawing.Color]::FromArgb(255, 193, 7)
                    $script:RiskLevelLabel.ForeColor = [System.Drawing.Color]::Black
                }
                "High" { 
                    $script:RiskLevelLabel.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
                    $script:RiskLevelLabel.ForeColor = [System.Drawing.Color]::White
                }
                default {
                    $script:RiskLevelLabel.BackColor = [System.Drawing.Color]::LightGray
                    $script:RiskLevelLabel.ForeColor = [System.Drawing.Color]::Black
                }
            }
            
            # Update restart required indicator
            if ($scriptInfo.RequiresRestart) {
                $script:RestartLabel.Text = "Restart Required"
                $script:RestartLabel.Visible = $true
            }
            else {
                $script:RestartLabel.Visible = $false
            }
            
            # Check compatibility if available
            try {
                if (Get-Command "Test-ScriptCompatibility" -ErrorAction SilentlyContinue) {
                    $compatibility = Test-ScriptCompatibility -ScriptPath $scriptInfo.FilePath
                    if ($compatibility.IsCompatible) {
                        $script:CompatibilityLabel.Text = "✅ Compatible"
                        $script:CompatibilityLabel.ForeColor = [System.Drawing.Color]::Green
                    }
                    else {
                        $script:CompatibilityLabel.Text = "⚠️ Compatibility issues detected"
                        $script:CompatibilityLabel.ForeColor = [System.Drawing.Color]::Orange
                    }
                }
                else {
                    $script:CompatibilityLabel.Text = "Compatibility: Not checked"
                    $script:CompatibilityLabel.ForeColor = [System.Drawing.Color]::Gray
                }
            }
            catch {
                $script:CompatibilityLabel.Text = "Compatibility: Unknown"
                $script:CompatibilityLabel.ForeColor = [System.Drawing.Color]::Gray
            }
            
            # Enable buttons
            $script:RunSingleButton.Enabled = $true
            $script:ViewScriptButton.Enabled = $true
            $script:BackupInfoButton.Enabled = $true
            $script:PreviewButton.Enabled = $true
            $script:RunSingleButton.Tag = $selectedNode.Tag
        }
        else {
            # Category selected
            $script:ScriptNameLabel.Text = "Category: " + $selectedNode.Tag.Name
            $script:ScriptDescriptionLabel.Text = "Select a script to view details"
            $script:ScriptPathLabel.Text = ""
            $script:LastModifiedLabel.Text = ""
            $script:CompatibilityLabel.Text = ""
            $script:RiskLevelLabel.Text = ""
            $script:RestartLabel.Visible = $false
            
            # Disable buttons
            $script:RunSingleButton.Enabled = $false
            $script:ViewScriptButton.Enabled = $false
            $script:BackupInfoButton.Enabled = $false
            $script:PreviewButton.Enabled = $false
        }
    })
    
    # Run single script button
    $script:RunSingleButton.add_Click({
        if ($script:RunSingleButton.Tag) {
            $scriptInfo = $script:RunSingleButton.Tag.Info
            Start-SingleScript -ScriptInfo $scriptInfo
        }
    })
    
    # View script button
    $script:ViewScriptButton.add_Click({
        if ($script:RunSingleButton.Tag) {
            $scriptInfo = $script:RunSingleButton.Tag.Info
            try {
                Start-Process -FilePath "notepad.exe" -ArgumentList "`"$($scriptInfo.FilePath)`""
            }
            catch {
                Add-LogEntry "Error opening script file: $($_.Exception.Message)" "ERROR"
            }
        }
    })
    
    # Backup info button
    $script:BackupInfoButton.add_Click({
        if ($script:RunSingleButton.Tag) {
            $scriptInfo = $script:RunSingleButton.Tag.Info
            Show-ScriptBackupInfo -ScriptName $scriptInfo.DisplayName
        }
    })
    
    # Preview button
    $script:PreviewButton.add_Click({
        if ($script:RunSingleButton.Tag) {
            $scriptInfo = $script:RunSingleButton.Tag.Info
            Show-ScriptPreview -ScriptInfo $scriptInfo
        }
    })
    
    # Batch operation buttons
    $script:SelectAllButton.add_Click({
        for ($i = 0; $i -lt $script:CategoryCheckedListBox.Items.Count; $i++) {
            $script:CategoryCheckedListBox.SetItemChecked($i, $true)
        }
    })
    
    $script:ClearAllButton.add_Click({
        for ($i = 0; $i -lt $script:CategoryCheckedListBox.Items.Count; $i++) {
            $script:CategoryCheckedListBox.SetItemChecked($i, $false)
        }
    })
    
    $script:RunBatchButton.add_Click({
        $selectedCategories = @()
        for ($i = 0; $i -lt $script:CategoryCheckedListBox.Items.Count; $i++) {
            if ($script:CategoryCheckedListBox.GetItemChecked($i)) {
                $selectedCategories += $script:CategoryCheckedListBox.Items[$i]
            }
        }
        
        if ($selectedCategories.Count -gt 0) {
            Start-BatchOperation -Categories $selectedCategories
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one category.", "No Categories Selected", "OK", "Warning")
        }
    })
    
    # System tools buttons
    $script:HealthCheckButton.add_Click({ Start-SystemTool -Tool "health-check" })
    $script:ValidateButton.add_Click({ Start-SystemTool -Tool "validate" })
    $script:CleanupButton.add_Click({ Start-SystemTool -Tool "cleanup" })
    $script:BackupManagerButton.add_Click({ Show-BackupManager })
    $script:ConfigButton.add_Click({ Show-Configuration })
    $script:LogsButton.add_Click({ Show-LogViewer })
    
    # Control buttons
    $script:RefreshButton.add_Click({
        Refresh-Scripts
        # Refresh tree view
        $treeView.Nodes.Clear()
        
        # Repopulate tree with updated scripts
        foreach ($category in $script:ScriptCategories.Keys) {
            $categoryNode = New-Object System.Windows.Forms.TreeNode($category)
            $categoryNode.Tag = @{ Type = "Category"; Name = $category }
            $categoryNode.NodeFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            
            $scriptsInCategory = $script:ScriptCategories[$category]
            foreach ($scriptName in $scriptsInCategory) {
                if ($script:AvailableScripts.ContainsKey($scriptName)) {
                    $scriptInfo = $script:AvailableScripts[$scriptName]
                    $scriptNode = New-Object System.Windows.Forms.TreeNode($scriptInfo.DisplayName)
                    $scriptNode.Tag = @{ 
                        Type = "Script"
                        Name = $scriptName
                        Info = $scriptInfo
                    }
                    $categoryNode.Nodes.Add($scriptNode)
                }
            }
            
            if ($categoryNode.Nodes.Count -gt 0) {
                $treeView.Nodes.Add($categoryNode)
            }
        }
        
        $treeView.ExpandAll()
    })
    
    # Export button
    $script:ExportButton.add_Click({ Export-ScriptReport })
    
    # Statistics button
    $script:StatsButton.add_Click({ Show-Statistics })
    
    $script:HelpButton.add_Click({ Show-Help })
    $script:ExitButton.add_Click({ $form.Close() })
    
    # Form closing event
    $form.add_FormClosing({
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to exit ReSet Toolkit?", "Confirm Exit", "YesNo", "Question")
        if ($result -eq "No") {
            $args[1].Cancel = $true
        }
    })
}

# Function to start single script
function Start-SingleScript {
    param($ScriptInfo)
    
    # Enhanced confirmation dialog
    $confirmText = "Are you sure you want to run: $($ScriptInfo.DisplayName)?`n`n"
    $confirmText += "Risk Level: $($ScriptInfo.RiskLevel)`n"
    if ($ScriptInfo.RequiresRestart) {
        $confirmText += "⚠️ This script requires a system restart after completion.`n"
    }
    $confirmText += "`nThis will reset Windows settings and cannot be easily undone."
    
    $result = [System.Windows.Forms.MessageBox]::Show(
        $confirmText,
        "Confirm Script Execution - $($ScriptInfo.RiskLevel) Risk",
        "YesNo",
        "Warning"
    )
    
    if ($result -eq "Yes") {
        Add-LogEntry "Starting script: $($ScriptInfo.DisplayName)" "INFO"
        Update-Progress -Percentage 10 -Operation "Preparing to run script..."
        
        try {
            # Show progress dialog if available
            $progressDialog = $null
            try {
                if (Get-Command "Show-ProgressDialog" -ErrorAction SilentlyContinue) {
                    $progressDialog = Show-ProgressDialog -Title "Running Script" -Message "Executing: $($ScriptInfo.DisplayName)"
                    $progressDialog.Form.Show()
                }
            }
            catch {
                # Continue without progress dialog
            }
            
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$($ScriptInfo.FilePath)`"" -WindowStyle Hidden -PassThru
            
            Update-Progress -Percentage 50 -Operation "Running script: $($ScriptInfo.DisplayName)"
            
            $process.WaitForExit()
            
            # Close progress dialog
            if ($progressDialog) {
                $progressDialog.Form.Close()
            }
            
            if ($process.ExitCode -eq 0) {
                Add-LogEntry "Script completed successfully: $($ScriptInfo.DisplayName)" "SUCCESS"
                Update-Progress -Percentage 100 -Operation "Script completed successfully"
                
                if ($ScriptInfo.RequiresRestart) {
                    $restartResult = [System.Windows.Forms.MessageBox]::Show(
                        "Script completed successfully. A system restart is recommended.`n`nWould you like to restart now?",
                        "Restart Recommended",
                        "YesNo",
                        "Question"
                    )
                    if ($restartResult -eq "Yes") {
                        Start-Process -FilePath "shutdown.exe" -ArgumentList "/r /t 60 /c `"Restarting after ReSet Toolkit script execution`""
                    }
                }
            }
            else {
                Add-LogEntry "Script failed with exit code: $($process.ExitCode)" "ERROR"
                Update-Progress -Percentage 0 -Operation "Script execution failed"
                [System.Windows.Forms.MessageBox]::Show("Script execution failed with exit code: $($process.ExitCode)", "Script Failed", "OK", "Error")
            }
        }
        catch {
            Add-LogEntry "Error running script: $($_.Exception.Message)" "ERROR"
            Update-Progress -Percentage 0 -Operation "Script execution error"
            [System.Windows.Forms.MessageBox]::Show("Error running script: $($_.Exception.Message)", "Execution Error", "OK", "Error")
        }
    }
}

# Function to show script backup information
function Show-ScriptBackupInfo {
    param($ScriptName)
    
    $backupForm = New-Object System.Windows.Forms.Form
    $backupForm.Text = "Backup Information - $ScriptName"
    $backupForm.Size = New-Object System.Drawing.Size(600, 400)
    $backupForm.StartPosition = "CenterParent"
    $backupForm.FormBorderStyle = "FixedDialog"
    $backupForm.MaximizeBox = $false
    
    $infoText = New-Object System.Windows.Forms.RichTextBox
    $infoText.Size = New-Object System.Drawing.Size(560, 350)
    $infoText.Location = New-Object System.Drawing.Point(20, 20)
    $infoText.ReadOnly = $true
    $infoText.Font = New-Object System.Drawing.Font("Consolas", 9)
    
    # Get backup information
    $backupInfo = "Backup Information for: $ScriptName`n"
    $backupInfo += "=" * 50 + "`n`n"
    
    if (Test-Path $script:BackupsPath) {
        $backupFiles = Get-ChildItem -Path $script:BackupsPath -Recurse | Where-Object { $_.Name -like "*$ScriptName*" }
        
        if ($backupFiles.Count -gt 0) {
            $backupInfo += "Found $($backupFiles.Count) backup file(s):`n`n"
            foreach ($file in $backupFiles) {
                $backupInfo += "File: $($file.Name)`n"
                $backupInfo += "Created: $($file.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))`n"
                $backupInfo += "Size: $([math]::Round($file.Length / 1KB, 2)) KB`n"
                $backupInfo += "Path: $($file.FullName)`n"
                $backupInfo += "-" * 40 + "`n"
            }
        }
        else {
            $backupInfo += "No backup files found for this script.`n"
            $backupInfo += "Backups will be created automatically when the script runs.`n"
        }
    }
    else {
        $backupInfo += "Backup directory not found: $script:BackupsPath`n"
        $backupInfo += "Backups will be created automatically in this location.`n"
    }
    
    $backupInfo += "`n`nNote: Backups are created automatically before any script execution.`n"
    $backupInfo += "Use the restore-backup.bat script to restore from backups if needed."
    
    $infoText.Text = $backupInfo
    $backupForm.Controls.Add($infoText)
    $backupForm.ShowDialog()
}

# Function to show script preview
function Show-ScriptPreview {
    param($ScriptInfo)
    
    $previewForm = New-Object System.Windows.Forms.Form
    $previewForm.Text = "Preview Changes - $($ScriptInfo.DisplayName)"
    $previewForm.Size = New-Object System.Drawing.Size(700, 500)
    $previewForm.StartPosition = "CenterParent"
    $previewForm.FormBorderStyle = "Sizable"
    
    $previewText = New-Object System.Windows.Forms.RichTextBox
    $previewText.Size = New-Object System.Drawing.Size(660, 440)
    $previewText.Location = New-Object System.Drawing.Point(20, 20)
    $previewText.ReadOnly = $true
    $previewText.Font = New-Object System.Drawing.Font("Consolas", 9)
    $previewText.ScrollBars = "Both"
    
    # Analyze script to show what it will change
    $previewContent = "Script Preview: $($ScriptInfo.DisplayName)`n"
    $previewContent += "=" * 60 + "`n`n"
    $previewContent += "Description: $($ScriptInfo.Description)`n"
    $previewContent += "Risk Level: $($ScriptInfo.RiskLevel)`n"
    $previewContent += "Requires Restart: $($ScriptInfo.RequiresRestart)`n`n"
    
    try {
        $scriptContent = Get-Content $ScriptInfo.FilePath
        
        $previewContent += "ACTIONS THIS SCRIPT WILL PERFORM:`n"
        $previewContent += "-" * 40 + "`n"
        
        # Parse script for common operations
        $registryOperations = @()
        $fileOperations = @()
        $serviceOperations = @()
        
        foreach ($line in $scriptContent) {
            $line = $line.Trim()
            
            if ($line -match "reg (add|delete)" -and -not $line.StartsWith("::")) {
                $registryOperations += $line
            }
            elseif ($line -match "(del|copy|move|xcopy)" -and -not $line.StartsWith("::")) {
                $fileOperations += $line
            }
            elseif ($line -match "sc (start|stop|config)" -and -not $line.StartsWith("::")) {
                $serviceOperations += $line
            }
        }
        
        if ($registryOperations.Count -gt 0) {
            $previewContent += "`nRegistry Operations ($($registryOperations.Count)):`n"
            foreach ($op in $registryOperations | Select-Object -First 10) {
                $previewContent += "  • $op`n"
            }
            if ($registryOperations.Count -gt 10) {
                $previewContent += "  ... and $($registryOperations.Count - 10) more registry operations`n"
            }
        }
        
        if ($fileOperations.Count -gt 0) {
            $previewContent += "`nFile Operations ($($fileOperations.Count)):`n"
            foreach ($op in $fileOperations | Select-Object -First 5) {
                $previewContent += "  • $op`n"
            }
            if ($fileOperations.Count -gt 5) {
                $previewContent += "  ... and $($fileOperations.Count - 5) more file operations`n"
            }
        }
        
        if ($serviceOperations.Count -gt 0) {
            $previewContent += "`nService Operations ($($serviceOperations.Count)):`n"
            foreach ($op in $serviceOperations) {
                $previewContent += "  • $op`n"
            }
        }
        
        if ($registryOperations.Count -eq 0 -and $fileOperations.Count -eq 0 -and $serviceOperations.Count -eq 0) {
            $previewContent += "No specific operations detected in script analysis.`n"
            $previewContent += "This script may perform complex operations or use external tools.`n"
        }
        
        $previewContent += "`n" + "=" * 60 + "`n"
        $previewContent += "IMPORTANT NOTES:`n"
        $previewContent += "• All operations will create automatic backups before execution`n"
        $previewContent += "• Changes can be reverted using the restore-backup.bat script`n"
        $previewContent += "• Always run scripts with administrator privileges`n"
        $previewContent += "• Test in a virtual machine if unsure about the impact`n"
        
    }
    catch {
        $previewContent += "Error analyzing script: $($_.Exception.Message)`n"
        $previewContent += "Please review the script manually before execution."
    }
    
    $previewText.Text = $previewContent
    $previewForm.Controls.Add($previewText)
    $previewForm.ShowDialog()
}

# Function to start batch operation
function Start-BatchOperation {
    param($Categories)
    
    $categoryList = $Categories -join ", "
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Are you sure you want to run batch operation for categories:`n$categoryList`n`nThis will reset multiple Windows settings and cannot be easily undone.",
        "Confirm Batch Operation",
        "YesNo",
        "Warning"
    )
    
    if ($result -eq "Yes") {
        Add-LogEntry "Starting batch operation for: $categoryList" "INFO"
        
        $batchArgs = "--categories `"$($Categories -join ',')`""
        
        if ($script:CreateRestorePointCheckBox.Checked) {
            $batchArgs += " --create-restore-point"
        }
        
        if ($script:SilentModeCheckBox.Checked) {
            $batchArgs += " --silent"
        }
        
        $batchScriptPath = Join-Path $script:ResetRoot "batch-reset.bat"
        
        try {
            Update-Progress -Percentage 10 -Operation "Starting batch operation..."
            
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batchScriptPath`" $batchArgs" -WindowStyle Normal -PassThru
            
            Update-Progress -Percentage 50 -Operation "Running batch operation..."
            
            $process.WaitForExit()
            
            if ($process.ExitCode -eq 0) {
                Add-LogEntry "Batch operation completed successfully" "SUCCESS"
                Update-Progress -Percentage 100 -Operation "Batch operation completed"
            }
            else {
                Add-LogEntry "Batch operation failed with exit code: $($process.ExitCode)" "ERROR"
                Update-Progress -Percentage 0 -Operation "Batch operation failed"
            }
        }
        catch {
            Add-LogEntry "Error running batch operation: $($_.Exception.Message)" "ERROR"
            Update-Progress -Percentage 0 -Operation "Batch operation error"
        }
    }
}

# Function to start system tool
function Start-SystemTool {
    param($Tool)
    
    $toolPath = Join-Path $script:ResetRoot "$Tool.bat"
    
    if (Test-Path $toolPath) {
        Add-LogEntry "Starting system tool: $Tool" "INFO"
        
        try {
            $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$toolPath`"" -WindowStyle Normal -PassThru
            $process.WaitForExit()
            
            Add-LogEntry "System tool completed: $Tool" "SUCCESS"
        }
        catch {
            Add-LogEntry "Error running system tool: $($_.Exception.Message)" "ERROR"
        }
    }
    else {
        Add-LogEntry "System tool not found: $Tool" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("System tool not found: $toolPath", "Tool Not Found", "OK", "Error")
    }
}

# Function to show help
function Show-Help {
    $helpText = @"
ReSet Toolkit - Windows Settings Reset GUI

OVERVIEW:
The ReSet Toolkit provides an easy-to-use interface for resetting various Windows settings to their default values.

HOW TO USE:
1. Select a script from the tree view on the left to see details
2. Click 'Run This Script' to execute individual scripts
3. Use the Batch Operations panel to run multiple categories
4. Use System Tools for maintenance and diagnostics

FEATURES:
• 22+ reset scripts covering all major Windows settings
• Automatic backup creation before changes
• System health monitoring and diagnostics
• Comprehensive logging and progress tracking
• Safe operation with confirmation dialogs

SAFETY:
• All operations create backups automatically
• System restore points can be created
• Confirmation required for all operations
• Operations can be undone using backup restore

For more information, see the README.md file in the installation directory.
"@

    [System.Windows.Forms.MessageBox]::Show($helpText, "ReSet Toolkit Help", "OK", "Information")
}

# Additional dialog functions
function Show-BackupManager {
    # Create backup manager window
    $backupForm = New-Object System.Windows.Forms.Form
    $backupForm.Text = "Backup Manager"
    $backupForm.Size = New-Object System.Drawing.Size(600, 400)
    $backupForm.StartPosition = "CenterParent"
    
    # Add backup list and controls
    $backupList = New-Object System.Windows.Forms.ListView
    $backupList.View = "Details"
    $backupList.Size = New-Object System.Drawing.Size(560, 300)
    $backupList.Location = New-Object System.Drawing.Point(20, 20)
    $backupList.FullRowSelect = $true
    $backupList.GridLines = $true
    
    # Add columns
    $backupList.Columns.Add("Name", 200)
    $backupList.Columns.Add("Date", 150)
    $backupList.Columns.Add("Size", 100)
    $backupList.Columns.Add("Type", 100)
    
    # Populate with backup files
    if (Test-Path $script:BackupsPath) {
        $backupFiles = Get-ChildItem -Path $script:BackupsPath -Recurse
        foreach ($file in $backupFiles) {
            $item = New-Object System.Windows.Forms.ListViewItem($file.Name)
            $item.SubItems.Add($file.LastWriteTime.ToString("yyyy-MM-dd HH:mm"))
            $item.SubItems.Add([math]::Round($file.Length / 1KB, 2).ToString() + " KB")
            $item.SubItems.Add($file.Extension)
            $backupList.Items.Add($item)
        }
    }
    
    $backupForm.Controls.Add($backupList)
    $backupForm.ShowDialog()
}

function Show-Configuration {
    # Create configuration window
    $configForm = New-Object System.Windows.Forms.Form
    $configForm.Text = "Configuration Settings"
    $configForm.Size = New-Object System.Drawing.Size(500, 400)
    $configForm.StartPosition = "CenterParent"
    
    # Add configuration controls here
    $configLabel = New-Object System.Windows.Forms.Label
    $configLabel.Text = "Configuration settings will be displayed here"
    $configLabel.Location = New-Object System.Drawing.Point(20, 20)
    $configLabel.Size = New-Object System.Drawing.Size(460, 300)
    
    $configForm.Controls.Add($configLabel)
    $configForm.ShowDialog()
}

function Show-LogViewer {
    # Create log viewer window
    $logForm = New-Object System.Windows.Forms.Form
    $logForm.Text = "Log Viewer"
    $logForm.Size = New-Object System.Drawing.Size(800, 600)
    $logForm.StartPosition = "CenterParent"
    
    # Add log text box
    $logViewer = New-Object System.Windows.Forms.RichTextBox
    $logViewer.Size = New-Object System.Drawing.Size(760, 550)
    $logViewer.Location = New-Object System.Drawing.Point(20, 20)
    $logViewer.Font = New-Object System.Drawing.Font("Consolas", 9)
    $logViewer.ReadOnly = $true
    $logViewer.ScrollBars = "Both"
    
    # Load recent log file
    if (Test-Path $script:LogsPath) {
        $latestLog = Get-ChildItem -Path $script:LogsPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestLog) {
            $logContent = Get-Content $latestLog.FullName -Raw
            $logViewer.Text = $logContent
        }
    }
    
    $logForm.Controls.Add($logViewer)
    $logForm.ShowDialog()
}

# Function to export script report
function Export-ScriptReport {
    try {
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Filter = "CSV files (*.csv)|*.csv|Text files (*.txt)|*.txt|HTML files (*.html)|*.html"
        $saveDialog.DefaultExt = "csv"
        $saveDialog.FileName = "ReSet_Scripts_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        
        if ($saveDialog.ShowDialog() -eq "OK") {
            $reportData = @()
            
            foreach ($scriptName in $script:AvailableScripts.Keys) {
                $scriptInfo = $script:AvailableScripts[$scriptName]
                $reportData += [PSCustomObject]@{
                    Name = $scriptInfo.DisplayName
                    Category = $scriptInfo.Category
                    RiskLevel = $scriptInfo.RiskLevel
                    RequiresRestart = $scriptInfo.RequiresRestart
                    LastModified = $scriptInfo.LastModified
                    FileSize = $scriptInfo.FileSize
                    Description = $scriptInfo.Description
                    FilePath = $scriptInfo.FilePath
                }
            }
            
            $extension = [System.IO.Path]::GetExtension($saveDialog.FileName)
            switch ($extension) {
                ".csv" {
                    $reportData | Export-Csv -Path $saveDialog.FileName -NoTypeInformation
                }
                ".html" {
                    $html = $reportData | ConvertTo-Html -Title "ReSet Toolkit Scripts Report" -PreContent "<h1>ReSet Toolkit Scripts Report</h1><p>Generated: $(Get-Date)</p>"
                    $html | Out-File -FilePath $saveDialog.FileName
                }
                default {
                    $reportData | Format-Table -AutoSize | Out-File -FilePath $saveDialog.FileName
                }
            }
            
            Add-LogEntry "Report exported to: $($saveDialog.FileName)" "SUCCESS"
            [System.Windows.Forms.MessageBox]::Show("Report exported successfully to:`n$($saveDialog.FileName)", "Export Complete", "OK", "Information")
        }
    }
    catch {
        Add-LogEntry "Error exporting report: $($_.Exception.Message)" "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Error exporting report: $($_.Exception.Message)", "Export Error", "OK", "Error")
    }
}

# Function to show statistics
function Show-Statistics {
    $statsForm = New-Object System.Windows.Forms.Form
    $statsForm.Text = "Script Statistics"
    $statsForm.Size = New-Object System.Drawing.Size(500, 400)
    $statsForm.StartPosition = "CenterParent"
    $statsForm.FormBorderStyle = "FixedDialog"
    $statsForm.MaximizeBox = $false
    
    $statsText = New-Object System.Windows.Forms.RichTextBox
    $statsText.Size = New-Object System.Drawing.Size(460, 350)
    $statsText.Location = New-Object System.Drawing.Point(20, 20)
    $statsText.ReadOnly = $true
    $statsText.Font = New-Object System.Drawing.Font("Consolas", 9)
    
    # Calculate statistics
    $totalScripts = $script:AvailableScripts.Count
    $categoryStats = @{}
    $riskStats = @{ Low = 0; Medium = 0; High = 0 }
    $restartRequired = 0
    $totalSize = 0
    
    foreach ($scriptInfo in $script:AvailableScripts.Values) {
        # Category stats
        if ($categoryStats.ContainsKey($scriptInfo.Category)) {
            $categoryStats[$scriptInfo.Category]++
        } else {
            $categoryStats[$scriptInfo.Category] = 1
        }
        
        # Risk stats
        if ($riskStats.ContainsKey($scriptInfo.RiskLevel)) {
            $riskStats[$scriptInfo.RiskLevel]++
        }
        
        # Restart stats
        if ($scriptInfo.RequiresRestart) {
            $restartRequired++
        }
        
        # Size stats
        if ($scriptInfo.FileSize) {
            $totalSize += $scriptInfo.FileSize
        }
    }
    
    # Generate statistics text
    $statsContent = "RESET TOOLKIT SCRIPT STATISTICS`n"
    $statsContent += "=" * 40 + "`n`n"
    $statsContent += "OVERVIEW:`n"
    $statsContent += "Total Scripts: $totalScripts`n"
    $statsContent += "Total Size: $([math]::Round($totalSize / 1KB, 2)) KB`n"
    $statsContent += "Scripts Requiring Restart: $restartRequired`n`n"
    
    $statsContent += "RISK LEVEL DISTRIBUTION:`n"
    foreach ($risk in @("Low", "Medium", "High")) {
        $count = $riskStats[$risk]
        $percentage = if ($totalScripts -gt 0) { [math]::Round(($count / $totalScripts) * 100, 1) } else { 0 }
        $statsContent += "$risk Risk: $count ($percentage%)`n"
    }
    
    $statsContent += "`nCATEGORY DISTRIBUTION:`n"
    foreach ($category in $categoryStats.Keys | Sort-Object) {
        $count = $categoryStats[$category]
        $percentage = if ($totalScripts -gt 0) { [math]::Round(($count / $totalScripts) * 100, 1) } else { 0 }
        $statsContent += "$category`: $count ($percentage%)`n"
    }
    
    $statsContent += "`nSYSTEM INFORMATION:`n"
    $statsContent += "PowerShell Version: $($PSVersionTable.PSVersion)`n"
    $statsContent += "OS Version: $([System.Environment]::OSVersion.VersionString)`n"
    $statsContent += "GUI Version: 2.1 Enhanced`n"
    $statsContent += "Last Scan: $($script:LastScanTime)`n"
    
    $statsText.Text = $statsContent
    $statsForm.Controls.Add($statsText)
    $statsForm.ShowDialog()
}

# Main application entry point
function Start-ReSetGUI {
    # Check if running as administrator
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        [System.Windows.Forms.MessageBox]::Show(
            "This application requires administrator privileges to function properly.`n`nPlease run as administrator.",
            "Administrator Rights Required",
            "OK",
            "Warning"
        )
        return
    }
    
    # Create main form
    $script:MainForm = New-MainForm
    
    # Create all panels and controls
    New-HeaderPanel $script:MainForm
    $treeView = New-ScriptTreeView $script:MainForm
    New-DetailsPanel $script:MainForm
    New-BatchPanel $script:MainForm
    New-SystemToolsPanel $script:MainForm
    New-ProgressPanel $script:MainForm
    New-LogPanel $script:MainForm
    New-ControlButtons $script:MainForm
    
    # Register event handlers
    Register-EventHandlers $script:MainForm $treeView
    
    # Initialize
    Add-LogEntry "ReSet Toolkit GUI started successfully" "INFO"
    Add-LogEntry "Found $($script:AvailableScripts.Count) reset scripts" "INFO"
    
    # Show the form
    [System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::Run($script:MainForm)
}

# Start the application
Start-ReSetGUI