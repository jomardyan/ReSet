# Windows Settings Reset Toolkit - Audio Settings Reset
# Resets default playbook/recording devices, audio enhancements, and volume levels

param(
    [switch]$Silent,
    [switch]$VerifyBackup,
    [string]$BackupPath
)

# Set window title
$Host.UI.RawUI.WindowTitle = "ReSet - Audio Settings Reset"

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

Write-LogMessage -Level "INFO" -Message "Starting Audio Settings Reset"
Test-WindowsVersion | Out-Null

# Confirm action
if (-not (Confirm-Action -Action "reset all audio settings to defaults")) {
    exit 1
}

# Create backups
Write-LogMessage -Level "INFO" -Message "Creating registry backups..."
Backup-Registry -RegistryKey "HKEY_CURRENT_USER\Software\Microsoft\Multimedia\Audio" -BackupName "audio_settings"
Backup-Registry -RegistryKey "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices" -BackupName "audio_devices"

# Stop audio services temporarily
Write-LogMessage -Level "INFO" -Message "Stopping audio services..."
try {
    Stop-Service -Name "AudioSrv" -Force -ErrorAction SilentlyContinue
    Stop-Service -Name "AudioEndpointBuilder" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not stop audio services: $($_.Exception.Message)"
}

# Reset default audio devices
Write-LogMessage -Level "INFO" -Message "Resetting default audio devices..."
try {
    # Check if AudioDeviceCmdlets module is available
    if (Get-Module -ListAvailable -Name "AudioDeviceCmdlets") {
        Import-Module AudioDeviceCmdlets -Force
        
        # Get the first available playback device and set as default
        $playbackDevices = Get-AudioDevice -List | Where-Object { $_.Type -eq 'Playbook' }
        if ($playbackDevices) {
            $firstPlayback = $playbackDevices | Select-Object -First 1
            Set-AudioDevice -Index $firstPlayback.Index -DefaultOnly
            Write-LogMessage -Level "SUCCESS" -Message "Default playback device reset"
        }
        
        # Get the first available recording device and set as default
        $recordingDevices = Get-AudioDevice -List | Where-Object { $_.Type -eq 'Recording' }
        if ($recordingDevices) {
            $firstRecording = $recordingDevices | Select-Object -First 1
            Set-AudioDevice -Index $firstRecording.Index -DefaultOnly
            Write-LogMessage -Level "SUCCESS" -Message "Default recording device reset"
        }
    } else {
        # Alternative method using Windows API via PowerShell
        Add-Type -TypeDefinition @"
            using System;
            using System.Runtime.InteropServices;
            public class AudioDeviceHelper {
                [DllImport("winmm.dll")]
                public static extern int waveOutSetVolume(IntPtr hwo, uint dwVolume);
                
                [DllImport("winmm.dll")]
                public static extern int waveOutGetVolume(IntPtr hwo, out uint dwVolume);
            }
"@ -ErrorAction SilentlyContinue
        
        Write-LogMessage -Level "INFO" -Message "Audio device reset completed using alternative method"
    }
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not reset default audio devices: $($_.Exception.Message)"
}

# Reset audio enhancements
Write-LogMessage -Level "INFO" -Message "Disabling audio enhancements..."
try {
    # Disable audio enhancements for all render devices
    $renderDevicesPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render"
    if (Test-Path $renderDevicesPath) {
        $renderDevices = Get-ChildItem -Path $renderDevicesPath -ErrorAction SilentlyContinue
        foreach ($device in $renderDevices) {
            $fxPropertiesPath = Join-Path $device.PSPath "FxProperties"
            if (Test-Path $fxPropertiesPath) {
                Set-RegistryValue -Path $fxPropertiesPath -Name "{fc52a749-4be9-4510-896e-966ba6525980},3" -Value 0 -Type "DWord"
            }
        }
    }
    Write-LogMessage -Level "SUCCESS" -Message "Audio enhancements disabled"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not disable audio enhancements: $($_.Exception.Message)"
}

# Reset system volume to 50%
Write-LogMessage -Level "INFO" -Message "Resetting system volume..."
try {
    # Use Windows Forms to send volume keys
    Add-Type -AssemblyName System.Windows.Forms
    
    # Set volume to 50% by first muting, then setting to half
    for ($i = 0; $i -lt 50; $i++) {
        [System.Windows.Forms.SendKeys]::SendWait([char]174)  # Volume Down
        Start-Sleep -Milliseconds 50
    }
    for ($i = 0; $i -lt 25; $i++) {
        [System.Windows.Forms.SendKeys]::SendWait([char]175)  # Volume Up
        Start-Sleep -Milliseconds 50
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "System volume reset to approximately 50%"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not reset system volume: $($_.Exception.Message)"
}

# Reset sound scheme to Windows default
Write-LogMessage -Level "INFO" -Message "Resetting sound scheme..."
try {
    Set-RegistryValue -Path "HKCU:\AppEvents\Schemes" -Name "(Default)" -Value ".Default" -Type "String"
    
    # Reset individual sound events to default
    $soundEvents = @(
        "SystemAsterisk", "SystemExclamation", "SystemExit", "SystemHand",
        "SystemNotification", "SystemQuestion", "SystemStart", "WindowsLogoff", "WindowsLogon"
    )
    
    foreach ($soundEvent in $soundEvents) {
        $eventPath = "HKCU:\AppEvents\Schemes\Apps\.Default\$soundEvent\.Default"
        if (Test-Path (Split-Path $eventPath -Parent)) {
            Set-RegistryValue -Path (Split-Path $eventPath -Parent) -Name ".Default" -Value "" -Type "String"
        }
    }
    
    Write-LogMessage -Level "SUCCESS" -Message "Sound scheme reset to Windows default"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not reset sound scheme: $($_.Exception.Message)"
}

# Reset audio quality settings
Write-LogMessage -Level "INFO" -Message "Resetting audio quality settings..."
try {
    # Reset audio quality to CD quality (44.1 kHz, 16-bit)
    $audioPath = "HKCU:\Software\Microsoft\Multimedia\Audio"
    if (Test-Path $audioPath) {
        Set-RegistryValue -Path $audioPath -Name "UserSimulatedQuality" -Value 2 -Type "DWord"
    }
    Write-LogMessage -Level "SUCCESS" -Message "Audio quality settings reset"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not reset audio quality settings: $($_.Exception.Message)"
}

# Reset spatial audio settings
Write-LogMessage -Level "INFO" -Message "Resetting spatial audio settings..."
try {
    $spatialAudioPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
    if (Test-Path $spatialAudioPath) {
        Set-RegistryValue -Path $spatialAudioPath -Name "AudioEncodingBitrate" -Value 128000 -Type "DWord"
    }
    Write-LogMessage -Level "SUCCESS" -Message "Spatial audio settings reset"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not reset spatial audio settings: $($_.Exception.Message)"
}

# Start audio services
Write-LogMessage -Level "INFO" -Message "Starting audio services..."
try {
    Start-Service -Name "AudioEndpointBuilder" -ErrorAction SilentlyContinue
    Start-Service -Name "AudioSrv" -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Write-LogMessage -Level "SUCCESS" -Message "Audio services started"
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not start audio services: $($_.Exception.Message)"
}

# Final verification
Write-LogMessage -Level "INFO" -Message "Verifying audio system status..."
try {
    $audioService = Get-Service -Name "AudioSrv" -ErrorAction SilentlyContinue
    if ($audioService -and $audioService.Status -eq "Running") {
        Write-LogMessage -Level "SUCCESS" -Message "Audio system verification passed"
    } else {
        Write-LogMessage -Level "WARN" -Message "Audio service may not be running properly"
    }
} catch {
    Write-LogMessage -Level "WARN" -Message "Could not verify audio system status: $($_.Exception.Message)"
}

Write-LogMessage -Level "SUCCESS" -Message "Audio Settings Reset completed"
Write-Host ""
Write-Host "Audio settings have been reset to defaults." -ForegroundColor Green
Write-Host "Backup created at: $global:LAST_BACKUP" -ForegroundColor Cyan
Write-Host "Log file: $global:LOG_FILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "Note: You may need to restart your applications to see all changes take effect." -ForegroundColor Yellow

Write-LogMessage -Level "INFO" -Message "Audio Settings Reset completed"
exit 0