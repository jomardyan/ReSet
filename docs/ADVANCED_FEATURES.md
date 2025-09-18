# ReSet Toolkit - Advanced Features Guide

## 🚀 Enhanced Features

The ReSet Toolkit has been upgraded with advanced features for better usability, safety, and system management.

### 🔧 New Core Features

#### 1. Configuration Management System
- **File**: `config.ini`
- **Manager**: `scripts/config.bat`
- **Features**:
  - Centralized configuration management
  - Customizable retention periods
  - User preferences storage
  - Safety settings control

**Usage:**
```cmd
scripts\config.bat show          # View current configuration
scripts\config.bat read          # Load configuration
scripts\config.bat set LogLevel DEBUG  # Change settings
```

#### 2. System Health Checker
- **File**: `health-check.bat`
- **Features**:
  - Comprehensive system analysis
  - Health scoring (0-100)
  - Automated recommendations
  - Component-specific diagnostics

**Usage:**
```cmd
health-check.bat                 # Run interactive health check
health-check.bat --silent        # Run silent health check
```

#### 3. Validation System
- **File**: `validate.bat`
- **Features**:
  - Complete installation validation
  - Script integrity checking
  - System compatibility testing
  - Configuration validation

**Usage:**
```cmd
validate.bat                     # Full validation
validate.bat --silent            # Silent validation
```

#### 4. Automatic Cleanup System
- **File**: `cleanup.bat`
- **Features**:
  - Automatic old file removal
  - Configurable retention periods
  - Space usage optimization
  - Corrupted file detection

**Usage:**
```cmd
cleanup.bat                      # Interactive cleanup
cleanup.bat --silent             # Automatic cleanup
```

### 🛡️ Enhanced Safety Features

#### 1. Improved Backup System
- **Registry backup verification**
- **File integrity checking**
- **Rollback protection**
- **Compression support**

#### 2. Enhanced Error Handling
- **Graceful failure recovery**
- **User-friendly error messages**
- **Continuation options**
- **Detailed error logging**

#### 3. Better User Confirmations
- **Clear warning messages**
- **Color-coded output**
- **Explicit confirmation requirements**
- **Cancel options at any time**

### 🎨 User Experience Improvements

#### 1. Color-Coded Output
- **🔴 Red**: Errors and critical issues
- **🟡 Yellow**: Warnings and cautions  
- **🟢 Green**: Success messages
- **🔵 Blue**: Information and progress
- **🟣 Purple**: System status

#### 2. Progress Indicators
- **Visual progress bars**
- **Operation status display**
- **Time estimation**
- **Completion percentage**

#### 3. Comprehensive Logging
- **Timestamped entries**
- **Multiple log levels**
- **Automatic log rotation**
- **Operation tracking**

### 📊 System Monitoring

#### 1. Health Scoring System
- **Overall Health**: Combined system score
- **Performance Health**: CPU, memory, disk usage
- **Security Health**: Defender, UAC, updates
- **Stability Health**: Services, network, files
- **Storage Health**: Disk space, cleanup needs

#### 2. Automated Recommendations
- **High Priority**: Critical issues requiring immediate attention
- **Medium Priority**: Important issues to address soon
- **Low Priority**: Optional improvements for optimization

#### 3. Health Reports
- **Detailed analysis results**
- **Trend tracking over time**
- **Recommendation history**
- **System comparison metrics**

### ⚙️ Configuration Options

#### Settings Categories:

**[Settings]**
- `LogLevel`: DEBUG, INFO, WARN, ERROR
- `LogRetentionDays`: Number of days to keep logs
- `BackupRetentionDays`: Number of days to keep backups  
- `CreateBackups`: Enable/disable automatic backups
- `CreateRestorePoint`: Enable/disable restore points
- `RequireConfirmation`: Require user confirmation
- `SilentMode`: Run without user interaction
- `SafeModeEnabled`: Enable extra safety checks

**[Paths]**
- `LogDirectory`: Location for log files
- `BackupDirectory`: Location for backup files
- `ScriptsDirectory`: Location for reset scripts

**[Advanced]**
- `ExperimentalFeatures`: Enable beta features
- `DebugMode`: Detailed debugging output
- `ParallelExecution`: Run multiple operations simultaneously

### 🔧 Maintenance Commands

#### Daily Maintenance
```cmd
health-check.bat --silent        # Check system health
cleanup.bat --silent             # Clean old files (if needed)
```

#### Weekly Maintenance  
```cmd
validate.bat                     # Validate installation
health-check.bat                 # Full health analysis
```

#### Monthly Maintenance
```cmd
cleanup.bat                      # Deep cleanup
# Review health reports
# Update configuration as needed
```

### 📈 Advanced Usage Examples

#### Automated Health Monitoring
```cmd
@echo off
health-check.bat --silent
if %errorlevel% gtr 1 (
    echo Critical system issues detected!
    health-check.bat
    pause
)
```

#### Scheduled Cleanup
```cmd
@echo off
cleanup.bat --silent
if %errorlevel% == 0 (
    echo Cleanup completed successfully
) else (
    echo Cleanup encountered errors - check logs
)
```

#### Configuration Management
```cmd
# Backup current configuration
copy config.ini config.backup

# Set development mode
scripts\config.bat set DebugMode true
scripts\config.bat set LogLevel DEBUG

# Restore configuration
copy config.backup config.ini
```

### 🛠️ Troubleshooting

#### Common Issues:

1. **Configuration Not Loading**
   - Check `config.ini` file exists
   - Run `scripts\config.bat validate`
   - Verify file permissions

2. **Health Check Fails**
   - Ensure administrator privileges
   - Check system resources
   - Review health check logs

3. **Cleanup Not Working**
   - Verify retention day settings
   - Check disk permissions
   - Review cleanup logs

4. **Validation Errors**
   - Run `validate.bat` for details
   - Check missing files
   - Verify installation integrity

### 🔗 Integration

The enhanced features integrate seamlessly with existing ReSet functionality:

- **All reset scripts** now use enhanced error handling
- **Batch operations** include progress indicators  
- **Configuration settings** apply to all operations
- **Health monitoring** tracks reset effectiveness
- **Cleanup system** maintains optimal performance

### 📝 Best Practices

1. **Run health checks** before major reset operations
2. **Review recommendations** from health analysis
3. **Use configuration management** for consistent settings
4. **Schedule regular cleanup** to maintain performance
5. **Validate installation** after system changes
6. **Monitor health trends** over time for proactive maintenance

---

For additional help and support, see the main README.md file or check the logs directory for detailed operation information.