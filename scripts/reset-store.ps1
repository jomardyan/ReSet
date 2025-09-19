# Windows Settings Reset Toolkit - Windows Store Reset
# Clears Microsoft Store cache and resets store preferences

param(
    [switch]$Silent,
    [switch]$VerifyBackup,
    [string]$BackupPath
)

# Set window title
$Host.UI.RawUI.WindowTitle = "ReSet - Windows Store Reset"

# Import utils module
$utilsPath = Join-Path $PSScriptRoot "utils.ps1"
if (Test-Path $utilsPath) {
    Import-Module $utilsPath -Force -Global
} else {
    Write-Error "Utils module not found: $utilsPath"
    exit 1
}

# Initialize global variables from parameters
$global:SILENT_MODE = $Silent.IsPresent
$global:VERIFY_BACKUP = $VerifyBackup.IsPresent
if ($BackupPath) { $global:BACKUP_DIR = $BackupPath }

Write-LogMessage -Level "INFO" -Message "Starting Windows Store Reset"
Test-WindowsVersion | Out-Null

# Confirm action
if (-not (Confirm-Action -Action "reset Windows Store cache and settings")) {
    exit 1
}

# Create backups
Write-LogMessage -Level "INFO" -Message "Creating registry backups..."
Backup-Registry -RegistryKey "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Store" -BackupName "store_settings"

# Close Windows Store
Write-LogMessage -Level "INFO" -Message "Closing Windows Store..."
try {
    Stop-ProcessSafely -ProcessName "WinStore.App"
    Stop-ProcessSafely -ProcessName "Microsoft.WindowsStore_8wekyb3d8bbwe"
    
    # Also stop any UWP store processes
    Get-Process | Where-Object { $_.ProcessName -like "*WindowsStore*" -or $_.ProcessName -like "*WinStore*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    Start-Sleep -Seconds 2
    Write-LogMessage -Level "SUCCESS" -Message "Windows Store processes closed"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not close all Store processes: $($_.Exception.Message)"
}

# Reset Windows Store cache using wsreset
Write-LogMessage -Level "INFO" -Message "Resetting Windows Store cache..."
try {
    $wsresetResult = Start-Process -FilePath "wsreset.exe" -WindowStyle Hidden -PassThru -Wait
    
    if ($wsresetResult.ExitCode -eq 0) {
        Write-LogMessage -Level "SUCCESS" -Message "Windows Store cache reset completed"
    } else {
        Write-LogMessage -Level "WARN" -Message "WSReset may have encountered issues"
    }
} catch {
    Write-LogMessage -Level "WARN" -Message "Error running wsreset: $($_.Exception.Message)"
}

# Clear Store cache directories
Write-LogMessage -Level "INFO" -Message "Clearing Store cache directories..."
try {
    $storeCachePath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache"
    $storeTempPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\TempState"
    $storeRoamingPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\RoamingState"
    
    if (Test-Path $storeCachePath) {
        Clear-Folder -FolderPath $storeCachePath -FolderName "Store Cache"
    }
    
    if (Test-Path $storeTempPath) {
        Clear-Folder -FolderPath $storeTempPath -FolderName "Store Temp"
    }
    
    if (Test-Path $storeRoamingPath) {
        Clear-Folder -FolderPath $storeRoamingPath -FolderName "Store Roaming"
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "Store cache directories cleared"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not clear all cache directories: $($_.Exception.Message)"
}

# Reset Store preferences
Write-LogMessage -Level "INFO" -Message "Resetting Store preferences..."
try {
    # Remove Store configuration registry keys
    Remove-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Store\Configuration" -Recurse -Force -ErrorAction SilentlyContinue
    
    # Reset Store user settings
    Remove-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Store" -Name "InstallForAllUsers"
    Remove-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Store" -Name "UpdatesAvailable"
    
    Write-LogMessage -Level "SUCCESS" -Message "Store preferences reset"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not reset all Store preferences: $($_.Exception.Message)"
}

# Reset Store app packages and licensing
Write-LogMessage -Level "INFO" -Message "Resetting Store app packages..."
try {
    # Reset Windows Store package
    $storePackage = Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue
    if ($storePackage) {
        Reset-AppxPackage -Package $storePackage.PackageFullName -ErrorAction SilentlyContinue
        Write-LogMessage -Level "SUCCESS" -Message "Windows Store package reset"
    }
    
    # Reset Xbox Identity Provider (often related to Store issues)
    $xboxPackage = Get-AppxPackage -Name "Microsoft.XboxIdentityProvider" -ErrorAction SilentlyContinue
    if ($xboxPackage) {
        Reset-AppxPackage -Package $xboxPackage.PackageFullName -ErrorAction SilentlyContinue
        Write-LogMessage -Level "SUCCESS" -Message "Xbox Identity Provider reset"
    }
    
    # Reset Microsoft Store Purchase App
    $purchasePackage = Get-AppxPackage -Name "Microsoft.StorePurchaseApp" -ErrorAction SilentlyContinue
    if ($purchasePackage) {
        Reset-AppxPackage -Package $purchasePackage.PackageFullName -ErrorAction SilentlyContinue
        Write-LogMessage -Level "SUCCESS" -Message "Store Purchase App reset"
    }
    
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not reset all Store packages: $($_.Exception.Message)"
}

# Clear Windows Store licensing cache
Write-LogMessage -Level "INFO" -Message "Clearing Store licensing cache..."
try {
    $licensingPath = "$env:LOCALAPPDATA\Microsoft\Windows Store\Cache"
    if (Test-Path $licensingPath) {
        Clear-Folder -FolderPath $licensingPath -FolderName "Store Licensing Cache"
    }
    
    # Clear additional Store cache locations
    $additionalCachePaths = @(
        "$env:PROGRAMDATA\Microsoft\Windows\AppRepository",
        "$env:LOCALAPPDATA\Microsoft\Windows Store"
    )
    
    foreach ($cachePath in $additionalCachePaths) {
        if (Test-Path $cachePath) {
            Get-ChildItem -Path $cachePath -Filter "*.cache" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "Store licensing cache cleared"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not clear all licensing cache: $($_.Exception.Message)"
}

# Reset Store download cache
Write-LogMessage -Level "INFO" -Message "Clearing Store download cache..."
try {
    $downloadPaths = @(
        "$env:PROGRAMDATA\Microsoft\Windows\AppRepository",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState"
    )
    
    foreach ($downloadPath in $downloadPaths) {
        if (Test-Path $downloadPath) {
            Get-ChildItem -Path $downloadPath -Name "*.tmp" -Recurse -ErrorAction SilentlyContinue | 
                ForEach-Object { Remove-Item (Join-Path $downloadPath $_) -Force -ErrorAction SilentlyContinue }
        }
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "Store download cache cleared"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not clear download cache: $($_.Exception.Message)"
}

Write-LogMessage -Level "SUCCESS" -Message "Windows Store Reset completed"
Write-Host ""
Write-Host "Windows Store has been reset." -ForegroundColor Green
Write-Host "• Store cache cleared" -ForegroundColor White
Write-Host "• Store preferences reset" -ForegroundColor White
Write-Host "• Store licensing reset" -ForegroundColor White
Write-Host "• Store app packages reset" -ForegroundColor White
Write-Host ""
Write-Host "Backup created at: $global:LAST_BACKUP" -ForegroundColor Cyan
Write-Host "Log file: $global:LOG_FILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: You may need to sign in to the Store again after this reset." -ForegroundColor Yellow

Write-LogMessage -Level "INFO" -Message "Windows Store Reset completed"
exit 0
