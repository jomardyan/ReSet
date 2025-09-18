# ReSet Toolkit - PowerShell GUI Application

## Overview

The ReSet Toolkit GUI is a comprehensive, interactive PowerShell application that provides a user-friendly interface for the Windows Settings Reset Toolkit. Built with Windows Forms, it offers dynamic script detection, enhanced safety features, and professional-grade functionality.

## Features

### 🎯 Core Functionality
- **Dynamic Script Detection**: Automatically scans and categorizes all reset scripts
- **Interactive Tree View**: Organized script browser with expandable categories
- **Real-time Information**: Live script details, compatibility checks, and metadata
- **Batch Operations**: Execute multiple scripts by category with advanced options
- **Progress Tracking**: Visual progress bars and detailed operation logs

### 🛡️ Safety & Security
- **Risk Level Indicators**: Clear visual indicators for script risk levels (Low/Medium/High)
- **Restart Requirements**: Automatic detection and handling of restart-required scripts
- **Compatibility Checking**: Real-time validation of script compatibility
- **Preview Mode**: Preview script changes before execution
- **Enhanced Confirmations**: Detailed confirmation dialogs with risk information

### 🎨 User Experience
- **Professional Interface**: Modern Windows Forms design with consistent styling
- **Responsive Layout**: Resizable windows with proper anchor handling
- **Enhanced Tooltips**: Contextual help and information tooltips
- **Color-coded Logging**: Real-time operation log with color-coded message types
- **Theme Support**: Light/Dark theme support via configuration

### 🔧 System Integration
- **Configuration Management**: INI-based configuration with dynamic loading
- **Backup Integration**: Built-in backup information and restore point management
- **Health Monitoring**: Integration with system health checking tools
- **Log Management**: Comprehensive logging with viewer integration
- **Administrative Checks**: Automatic administrator privilege validation

## Architecture

### Modular Design
```
ReSet Toolkit GUI/
├── ReSetGUI.ps1          # Main application entry point
├── GUIConfig.psm1        # Configuration and utility module
└── start-gui.bat         # Launcher script with safety checks
```

### Key Components

#### 1. Main Form (`New-MainForm`)
- Responsive main window with configurable size
- Theme support and professional styling
- Dynamic sizing based on configuration

#### 2. Script Tree View (`New-ScriptTreeView`)
- Hierarchical display of script categories
- Dynamic population from scripts folder
- Real-time selection handling

#### 3. Details Panel (`New-DetailsPanel`)
- Comprehensive script information display
- Risk level and restart requirement indicators
- Compatibility status and metadata
- Action buttons with enhanced functionality

#### 4. Batch Operations Panel (`New-BatchPanel`)
- Category-based batch execution
- Advanced options (restore points, silent mode, verification)
- Select all/clear all functionality

#### 5. System Tools Panel (`New-SystemToolsPanel`)
- Integration with system utilities
- Health checking, validation, cleanup tools
- Backup management and configuration access

#### 6. Progress and Logging (`New-ProgressPanel`, `New-LogPanel`)
- Real-time progress tracking
- Color-coded log output with timestamps
- Current operation display

## Configuration

### Configuration File (`config.ini`)
```ini
[UI]
Theme=Light
AutoRefresh=true
ShowTooltips=true
ConfirmActions=true
LogLevel=INFO
WindowWidth=1200
WindowHeight=800

[Advanced]
EnableDebugMode=false
MaxLogEntries=1000
AutoBackup=true
BackupRetentionDays=30

[Categories]
DisplayOrder=Language & Regional,Display & Audio,Network & Connectivity,Security & Privacy
```

### Configurable Elements
- **Window Size**: Customizable default window dimensions
- **Theme Selection**: Light/Dark theme support
- **Category Order**: Custom ordering of script categories
- **Feature Toggles**: Enable/disable tooltips, confirmations, auto-refresh
- **Logging Settings**: Configure log levels and retention

## Script Metadata Support

### Enhanced Script Information
The GUI supports enhanced metadata parsing from script files:

```batch
:: DisplayName: Network Settings Reset
:: Description: Resets all network adapters and TCP/IP stack settings
:: Category: Network & Connectivity
:: RequiresRestart: true
:: RiskLevel: Medium
:: EstimatedTime: 2-3 minutes
:: Prerequisites: Administrator privileges
:: AffectedAreas: Network adapters, TCP/IP, DNS
```

### Metadata Fields
- **DisplayName**: User-friendly script name
- **Description**: Detailed script description
- **Category**: Script categorization
- **RequiresRestart**: Boolean restart requirement
- **RiskLevel**: Low/Medium/High risk assessment
- **EstimatedTime**: Expected execution duration
- **Prerequisites**: Required conditions
- **AffectedAreas**: Systems/settings affected

## Advanced Features

### 1. Script Preview Mode
- Analyze script content before execution
- Display registry, file, and service operations
- Show operation counts and categories
- Safety recommendations and notes

### 2. Compatibility Checking
- Automatic Windows version validation
- Required tool availability checks
- PowerShell version requirements
- Feature dependency validation

### 3. Enhanced Progress Tracking
- Multi-level progress indication
- Current operation display
- Background process monitoring
- Completion status reporting

### 4. Backup Integration
- Automatic backup information display
- Backup file listing and details
- Creation time and size information
- Restore guidance and links

### 5. System Tools Integration
- Health checking integration
- Validation system access
- Cleanup tool integration
- Configuration management
- Log viewer with filtering

## Usage Instructions

### 1. Starting the GUI
```batch
# Using the launcher (recommended)
start-gui.bat

# Direct PowerShell execution
PowerShell -ExecutionPolicy Bypass -File "gui\ReSetGUI.ps1"
```

### 2. Basic Operations
1. **Select a Script**: Click on any script in the tree view
2. **Review Details**: Check script information, risk level, and compatibility
3. **Preview Changes**: Use the "Preview Changes" button to see what the script will do
4. **Execute**: Click "Run This Script" with enhanced confirmation
5. **Monitor Progress**: Watch real-time progress and log output

### 3. Batch Operations
1. **Select Categories**: Check desired categories in the batch panel
2. **Configure Options**: Set restore point, silent mode, and verification options
3. **Execute Batch**: Click "Run Selected Categories" for batch execution
4. **Monitor Results**: Track progress across multiple script executions

### 4. System Maintenance
1. **Health Check**: Run comprehensive system health analysis
2. **Validation**: Validate toolkit installation and script integrity
3. **Cleanup**: Perform automatic cleanup of old files and logs
4. **Backup Management**: View and manage backup files
5. **Configuration**: Adjust GUI and system settings

## Safety Features

### 1. Administrator Privilege Checks
- Automatic privilege validation on startup
- Clear error messages for insufficient permissions
- Guidance for proper execution

### 2. Enhanced Confirmations
- Risk level-specific confirmation dialogs
- Restart requirement warnings
- Detailed impact descriptions
- Cancel options at every stage

### 3. Backup Protection
- Automatic backup creation before script execution
- Backup verification and validation
- Restore point integration
- Recovery guidance and documentation

### 4. Compatibility Validation
- Real-time compatibility checking
- Warning display for potential issues
- Requirement validation
- Safe execution recommendations

## Troubleshooting

### Common Issues

#### 1. PowerShell Execution Policy
```powershell
# Error: Execution policy restriction
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 2. Administrator Privileges
```
Error: This application requires administrator privileges
Solution: Right-click start-gui.bat → "Run as administrator"
```

#### 3. Module Loading Issues
```
Warning: Could not load GUI configuration
Solution: Ensure GUIConfig.psm1 is in the same directory as ReSetGUI.ps1
```

#### 4. Script Detection Problems
```
Issue: No scripts detected in tree view
Solution: Verify scripts folder exists and contains reset-*.bat files
```

### Debug Mode
Enable debug mode in configuration for detailed troubleshooting:
```ini
[Advanced]
EnableDebugMode=true
```

## Performance Considerations

### Optimization Features
- **Lazy Loading**: Scripts loaded on-demand
- **Efficient Scanning**: Optimized script detection algorithms
- **Memory Management**: Proper disposal of resources
- **Background Processing**: Non-blocking operations where possible

### Resource Usage
- **Memory**: ~50-100MB typical usage
- **CPU**: Low impact during idle, moderate during operations
- **Disk**: Minimal I/O except during script execution
- **Network**: No network requirements

## Development and Customization

### Extending the GUI
1. **Adding New Panels**: Create panel functions following existing patterns
2. **Custom Themes**: Extend theme support in GUIConfig.psm1
3. **Additional Tools**: Add buttons to system tools panel
4. **Enhanced Metadata**: Extend script parsing capabilities

### Integration Points
- **Configuration System**: INI-based settings management
- **Logging Framework**: Centralized logging with color coding
- **Event Handling**: Comprehensive event registration system
- **Module System**: PowerShell module integration

## Security Considerations

### Best Practices
- Always run with appropriate administrator privileges
- Review script content before execution in production
- Test in virtual machines for unfamiliar scripts
- Maintain current backups before major operations
- Monitor system health after script execution

### Risk Mitigation
- Clear risk level indicators for all scripts
- Mandatory confirmation dialogs for high-risk operations
- Automatic backup creation and verification
- Restart requirement warnings and handling
- Comprehensive logging for audit trails

## Future Enhancements

### Planned Features
- **Remote Execution**: Network-based script execution
- **Scheduling**: Automated script scheduling capabilities
- **Reporting**: Detailed execution reports and analytics
- **Plugin System**: Extensible plugin architecture
- **Cloud Integration**: Backup and configuration synchronization

### Community Contributions
- Submit feature requests via GitHub issues
- Contribute script metadata improvements
- Enhance theme and styling options
- Extend compatibility checking capabilities
- Improve error handling and user experience

---

**Version**: 2.0  
**Compatibility**: Windows 10/11, PowerShell 5.0+  
**License**: MIT License  
**Support**: See main ReSet Toolkit documentation