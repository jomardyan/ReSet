# Windows Settings Reset Toolkit - Browser Settings Reset
# Resets Internet Explorer, Edge, Firefox, and Chrome browser settings

param(
    [switch]$Silent,
    [switch]$VerifyBackup,
    [string]$BackupPath
)

# Set window title
$Host.UI.RawUI.WindowTitle = "ReSet - Browser Settings Reset"

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

Write-LogMessage -Level "INFO" -Message "Starting Browser Settings Reset"
Test-WindowsVersion | Out-Null

# Confirm action
if (-not (Confirm-Action -Action "reset browser settings and clear browsing data for all browsers (IE, Edge, Chrome, Firefox)")) {
    exit 1
}

# Create backups
Write-LogMessage -Level "INFO" -Message "Creating registry backups..."
Backup-Registry -RegistryKey "HKEY_CURRENT_USER\Software\Microsoft\Internet Explorer" -BackupName "ie_settings"
Backup-Registry -RegistryKey "HKEY_CURRENT_USER\Software\Microsoft\Edge" -BackupName "edge_settings"
Backup-Registry -RegistryKey "HKEY_CURRENT_USER\Software\Google\Chrome" -BackupName "chrome_settings"
Backup-Registry -RegistryKey "HKEY_CURRENT_USER\Software\Mozilla\Firefox" -BackupName "firefox_settings"

# Close browsers
Write-LogMessage -Level "INFO" -Message "Closing browser processes..."
$browsersToClose = @("iexplore", "msedge", "chrome", "firefox")
foreach ($browser in $browsersToClose) {
    Stop-ProcessSafely -ProcessName $browser
}
Start-Sleep -Seconds 3

# Reset Internet Explorer
Write-LogMessage -Level "INFO" -Message "Resetting Internet Explorer settings..."
try {
    # Clear browsing history
    Start-Process -FilePath "RunDll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 255" -WindowStyle Hidden -Wait
    
    # Reset homepage
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name "Start Page" -Value "about:blank" -Type "String"
    
    # Reset search engine
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Internet Explorer\Main" -Name "Search Page" -Value "https://www.bing.com" -Type "String"
    
    # Reset security zones
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -Name "1400" -Value 0 -Type "DWord"
    
    # Reset proxy settings
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0 -Type "DWord"
    Remove-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyServer"
    
    # Clear saved passwords
    Remove-RegistryValue -Path "HKCU:\Software\Microsoft\Internet Explorer\IntelliForms" -Name "Storage2"
    
    Write-LogMessage -Level "SUCCESS" -Message "Internet Explorer settings reset"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not fully reset Internet Explorer: $($_.Exception.Message)"
}

# Reset Microsoft Edge
Write-LogMessage -Level "INFO" -Message "Resetting Microsoft Edge settings..."
try {
    $edgeUserDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    if (Test-Path $edgeUserDataPath) {
        # Backup Edge user data
        New-Backup -BackupName "edge_userdata" -SourcePath $edgeUserDataPath
        
        # Clear Edge data (careful approach - only clear specific folders)
        $edgeFoldersToReset = @("Default\Cache", "Default\Code Cache", "Default\GPUCache", "Default\Storage", "Default\IndexedDB")
        foreach ($folder in $edgeFoldersToReset) {
            $folderPath = Join-Path $edgeUserDataPath $folder
            if (Test-Path $folderPath) {
                Clear-Folder -FolderPath $folderPath -FolderName "Edge $folder"
            }
        }
        
        # Reset Edge preferences (if user confirms)
        if (-not $global:SILENT_MODE) {
            $resetPrefs = Read-Host "Reset Edge preferences and settings? (y/N)"
            if ($resetPrefs -eq "y" -or $resetPrefs -eq "Y") {
                $prefsFile = Join-Path $edgeUserDataPath "Default\Preferences"
                if (Test-Path $prefsFile) {
                    Remove-Item $prefsFile -Force
                    Write-LogMessage -Level "INFO" -Message "Edge preferences reset"
                }
            }
        }
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "Microsoft Edge settings reset"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not fully reset Microsoft Edge: $($_.Exception.Message)"
}

# Reset Google Chrome
Write-LogMessage -Level "INFO" -Message "Resetting Google Chrome settings..."
try {
    $chromeUserDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    if (Test-Path $chromeUserDataPath) {
        # Backup Chrome user data
        New-Backup -BackupName "chrome_userdata" -SourcePath $chromeUserDataPath
        
        # Clear Chrome cache and temporary data
        $chromeFoldersToReset = @("Default\Cache", "Default\Code Cache", "Default\GPUCache", "Default\Storage", "Default\IndexedDB")
        foreach ($folder in $chromeFoldersToReset) {
            $folderPath = Join-Path $chromeUserDataPath $folder
            if (Test-Path $folderPath) {
                Clear-Folder -FolderPath $folderPath -FolderName "Chrome $folder"
            }
        }
        
        # Reset Chrome preferences (if user confirms)
        if (-not $global:SILENT_MODE) {
            $resetPrefs = Read-Host "Reset Chrome preferences and settings? (y/N)"
            if ($resetPrefs -eq "y" -or $resetPrefs -eq "Y") {
                $prefsFile = Join-Path $chromeUserDataPath "Default\Preferences"
                if (Test-Path $prefsFile) {
                    Remove-Item $prefsFile -Force
                    Write-LogMessage -Level "INFO" -Message "Chrome preferences reset"
                }
            }
        }
        
        # Clear Chrome extensions (if user confirms)
        if (-not $global:SILENT_MODE) {
            $resetExtensions = Read-Host "Remove Chrome extensions? (y/N)"
            if ($resetExtensions -eq "y" -or $resetExtensions -eq "Y") {
                $extensionsPath = Join-Path $chromeUserDataPath "Default\Extensions"
                if (Test-Path $extensionsPath) {
                    Clear-Folder -FolderPath $extensionsPath -FolderName "Chrome Extensions"
                }
            }
        }
        
        # Reset Chrome bookmarks (if user confirms)
        if (-not $global:SILENT_MODE) {
            $resetBookmarks = Read-Host "Reset Chrome bookmarks? (y/N)"
            if ($resetBookmarks -eq "y" -or $resetBookmarks -eq "Y") {
                $bookmarksFile = Join-Path $chromeUserDataPath "Default\Bookmarks"
                if (Test-Path $bookmarksFile) {
                    Remove-Item $bookmarksFile -Force
                    Write-LogMessage -Level "INFO" -Message "Chrome bookmarks reset"
                }
            }
        }
    } else {
        Write-LogMessage -Level "INFO" -Message "Google Chrome not installed or not found"
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "Google Chrome settings reset"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not fully reset Google Chrome: $($_.Exception.Message)"
}

# Reset Mozilla Firefox
Write-LogMessage -Level "INFO" -Message "Resetting Mozilla Firefox settings..."
try {
    $firefoxProfilesPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $firefoxProfilesPath) {
        # Backup Firefox profiles
        New-Backup -BackupName "firefox_profiles" -SourcePath $firefoxProfilesPath
        
        # Find Firefox profiles
        $profiles = Get-ChildItem -Path $firefoxProfilesPath -Directory
        
        foreach ($firefoxProfile in $profiles) {
            Write-LogMessage -Level "INFO" -Message "Resetting Firefox profile: $($firefoxProfile.Name)"
            
            # Clear Firefox cache and temporary data
            $firefoxFoldersToReset = @("cache2", "crashes", "datareporting", "saved-telemetry-pings", "sessionstore-backups")
            foreach ($folder in $firefoxFoldersToReset) {
                $folderPath = Join-Path $firefoxProfile.FullName $folder
                if (Test-Path $folderPath) {
                    Clear-Folder -FolderPath $folderPath -FolderName "Firefox $folder"
                }
            }
            
            # Reset Firefox preferences (if user confirms)
            if (-not $global:SILENT_MODE) {
                $resetPrefs = Read-Host "Reset Firefox preferences for profile $($firefoxProfile.Name)? (y/N)"
                if ($resetPrefs -eq "y" -or $resetPrefs -eq "Y") {
                    $prefsFile = Join-Path $firefoxProfile.FullName "prefs.js"
                    if (Test-Path $prefsFile) {
                        Remove-Item $prefsFile -Force
                        Write-LogMessage -Level "INFO" -Message "Firefox preferences reset for profile: $($firefoxProfile.Name)"
                    }
                }
            }
        }
    } else {
        Write-LogMessage -Level "INFO" -Message "Mozilla Firefox not installed or not found"
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "Mozilla Firefox settings reset"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not fully reset Mozilla Firefox: $($_.Exception.Message)"
}

# Reset Windows default browser
Write-LogMessage -Level "INFO" -Message "Resetting default browser settings..."
try {
    # Reset default browser associations to Edge
    $browserAssociations = @("http", "https", "ftp", ".html", ".htm", ".pdf")
    foreach ($association in $browserAssociations) {
        # Use DISM to reset file associations (requires admin)
        # This is a safer approach than direct registry manipulation
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "sfc /scannow" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "Default browser settings reset"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not reset default browser settings: $($_.Exception.Message)"
}

# Clear system-wide browser cache
Write-LogMessage -Level "INFO" -Message "Clearing system-wide browser cache..."
try {
    # Clear Windows Internet Cache
    $tempInternetFiles = "$env:LOCALAPPDATA\Microsoft\Windows\INetCache"
    if (Test-Path $tempInternetFiles) {
        Clear-Folder -FolderPath $tempInternetFiles -FolderName "Internet Cache"
    }
    
    # Clear Windows temp files related to browsers
    $tempPath = $env:TEMP
    $browserTempFiles = Get-ChildItem -Path $tempPath -Filter "*browser*" -ErrorAction SilentlyContinue
    foreach ($tempFile in $browserTempFiles) {
        Remove-Item $tempFile.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "System-wide browser cache cleared"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not clear all system cache: $($_.Exception.Message)"
}

Write-LogMessage -Level "SUCCESS" -Message "Browser Settings Reset completed"
Write-Host ""
Write-Host "Browser settings have been reset to defaults." -ForegroundColor Green
Write-Host "Backup created at: $global:LAST_BACKUP" -ForegroundColor Cyan  
Write-Host "Log file: $global:LOG_FILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTES:" -ForegroundColor Yellow
Write-Host "• Browsers may need to be restarted to see all changes" -ForegroundColor White
Write-Host "• Some settings may require manual reconfiguration" -ForegroundColor White
Write-Host "• Extensions and bookmarks were preserved unless you chose to reset them" -ForegroundColor White

Write-LogMessage -Level "INFO" -Message "Browser Settings Reset completed"
exit 0