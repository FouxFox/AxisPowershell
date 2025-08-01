
@{
    RootModule = 'PSModule.psm1'
    GUID = '072c1e6d-39ea-4620-88b4-52d3a1156541'
    Author = 'Matt Small'
    Copyright = '(c) Matt Small. All rights reserved.'
    Description = "A module for managing Axis devices."
    PowerShellVersion = '3.0'
    #FormatsToProcess = ''
    FunctionsToExport = @(
        'Add-AxisParameter'
        'Add-AxisUserAccount'
        'Disable-AxisUnusedViews'
        'Enable-AxisDNSUpdate'
        'Export-AxisRecording'
        'Format-AxisSDCard'
        'Get-AxisAction'
        'Get-AxisContinuousRecordingProfile'
        'Get-AxisDate'
        'Get-AxisDeviceInfo'
        'Get-AxisDeviceStatus'
        'Get-AxisDSCP'
        'Get-AxisNetworkInfo'
        'Get-AxisNTPClient'
        'Get-AxisParameter'
        'Get-AxisPSConfig'
        'Get-AxisPSRecordingParams'
        'Get-AxisRecording'
        'Get-AxisRecordingProfile'
        'Get-AxisRecordingSupport'
        'Get-AxisSDCardStatus'
        'Get-AxisSnapshot'
        'Get-AxisStorageOptions'
        'Get-AxisStreamProfile'
        'Get-AxisStreamStatus'
        'Get-AxisSupportedResolutions'
        'Get-AxisUserAccount'
        'Get-AxisViewStatus'
        'Initialize-AxisDevice'
        'Invoke-AxisWebAPI'
        'Invoke-AxisProvisioningTask'
        'New-AxisProvisioningJob'
        'New-AxisRecordingProfile'
        'New-AxisStreamProfile'
        'Optimize-AxisRecordingProfiles'
        'Remove-AxisAction'
        'Remove-AxisParameter'
        'Remove-AxisPSRecordingParams'
        'Remove-AxisRecordingProfile'
        'Remove-AxisStreamProfile'
        'Reset-AxisDevice'
        'Restart-AxisDevice'
        'Set-AxisCredential'
        'Set-AxisDNSResolver'
        'Set-AxisDSCP'
        'Set-AxisIPv4Address'
        'Set-AxisNTPClient'
        'Set-AxisParameter'
        'Set-AxisPSConfig'
        'Set-AxisPSRecordingParams'
        'Set-AxisServices'
        'Set-AxisStorageOptions'
        'Set-AxisStreamProfile'
        'Set-AxisUserAccount'
        'Update-AxisDevice'
    )
    VariablesToExport = "*"
    AliasesToExport = "*"
    FileList = @(
        'PSModule.psm1'
    )
    RequiredModules = @(
        @{ModuleName='CredentialManager'; ModuleVersion='2.0'}
        @{ModuleName='IPV4Toolbox'; ModuleVersion='0.6.0'}
        @{ModuleName='PSLANSCAN'; ModuleVersion='1.2.0'}
    )
    HelpInfoURI = ''
    ModuleVersion = '1.1.2'
    PrivateData = @{
        PSData = @{
            Tags = @(
                'ManagedServiceProvider'
                'Windows'
            )
            IsPrerelease = $false
            ReleaseNotes = @'
## 1.1.2
    * Various fixes, security improvements, and code cleanup.
## 1.1.0
    * Added Get-AxisPSRecordingParams
    * Added Set-AxisPSRecordingParams
    * Added Remove-AxisPSRecordingParams
    * Created ability to define specific recording parameters on a per-model basis
## 1.0.0
    * Inital release.
    * Added documentation for AxisUserAccount cmdlets.
    * Code formatting and cleanup.
## 0.11.1
    * Added break between formatting and retention setting as some cameras would not take the retention setting in a timely maner.
## 0.11.0
    * Added Get-AxisDeviceStatus using SystemReady API
    * Added FactoryDefault option to Update-AxisDevice
    * Initialize-AxisDevice now checks devices status
    * Initialize-AxisDevice now sets password to the Stored Credential if no password is specified
    * Provisioning jobs now perform a factory default to account for the breaking changes in AxisOS 12.x
    * Provisioning jobs now encrypt the disk with the device password by default
    * Format-AxisSDCard now provides an option to encrypt the SD card
    * Fixed Set-AxisStorageOptions to set CleanupMaxAge for all SD cards
    * Fixed issue with New-AxisRecordingProfile where it would ignore the stream profile
## 0.10.2
    * Added Get-AxisNTPClient
    * Added Set-AxisNTPClient
    * Added Get-AxisRecording
    * Added Set-AxisDNSResolver
    * Added Export-AxisRecording
    * Changed Set-AxisIPAddress to Set-AxisIPv4Address (Old command will still work)
    * Added ability to use static addresses with Set-AxisIPv4Address    
    * Get-AxisNetworkInfo now returns the UPnP name of the device     
## 0.10.1
    * Fixed issue with Set-AxisDSCP
## 0.10.0
    * Get-AxisRecordingSupport now returns a comma separated list of supported codecs
    * Added New-, Get-, Set-, Remove- Stream Profile commands
    * Fixed New-AxisRecordingProfile to properly tie to a stream profile
    * Invoke-AxisProvisioningTask now creates a stream profile called "EdgeRecording" which is used by New-AxisRecordingProfile
    * Invoke-AxisProvisioningTask now sets sensible DSCP values
    * Added Get-AxisDSCP
## 0.9.0
    * Added support for setting DSCP values
## 0.8.4
    * Minor bugfix for singlethreaded behavior
## 0.8.3
    * Added Singlthreaded provisioning to try to resolve issues with runspaces
## 0.8.2
    * Fixed formatting issue with Update-AxisDevice
    * Fixed output in Restart-AxisDevice
    * Fixed issue where New-AxisRecordingProfile incorrectly counted SDCards.
## 0.8.0
    * Added support for customizing the directory provisioning snapshots are saved to
## 0.7.3
    * Issue with Refactor causing script not to run
## 0.7.2
    * Issue with Refactor causing script not to run
## 0.7.1
    * Hotfix release
    * Fixed issue with Set-AxisServices
    * Fixed issue with Progress display during a provisioning job
    * Fixed issues with logging to file
    * Fixed issue where Set-AxisPSConfig would not change the logging directory
## 0.7.0
    * Added AxisParameter cmdlets
    * Added Restart command
    * Refactored several cmdlets to use AxisParameter cmdlets
    * Changed behavior of Set-AxisServices to disable O3C by default
    * Combined PSConfig cmdlets into unified Set-AxisPSConfig / Get-AxisPSConfig
## 0.6.0
    * Refactored Provision-AxisDevice
    * Added logging to file
    * Added Snapshot stage to Provision-AxisDevice
    * Fixed issue with Get-AxisRecordingProfile where it would not display the correct number of lenses
    * New-AxisRecordingProfile now completes successfully when a profile already exists
    * Changed the way of interacting with the config
    * Added logging to Provision-AxisDevice
## 0.5.1
    * Documentation adjustments
## 0.5.0
    * Removed Provision-AxisDevice to get rid of Verb warnings
    * Added Get-AxisSnapshot
    * Added logic to suppress errors when another command has already set TrustAllCerts
    * Modified behavior for Get-AxisDeviceInfo to use param.cgi to increase compatibility with older models.
    * Added functions to manipulate Event-to-Action configurations from the camera
    * Get-AxisRecordingProfiles now returns action-based recording profiles
    * Added Optimize-AxisRecordingProfiles
## 0.4.6
    * Fixed issue with error reporting in New-AxisProvisioningJob
## 0.4.5
    * Fixed issue with Provision-AxisDevice where it called New-AxisRecordingProfile with the wrong parameter
    * Fixed issue with Format-AxisSDCard where it would not check if there was an SD card to format
## 0.4.4
    * Fixed issue with New-AxisProvisioningJob where it would not display progress or errors
    * Fixed issue with Set-AxisPSFactoryConfig where it would cause credential prompt on next command
## 0.4.3
    * Credential storage hotfix
## 0.4.2
    * Fixed issue with Get-AxisSDCardStatus where it would not display a disk number for SD Card 1
    * Added Lens count to Get-AxisRecordingSupport
    * Added multi-lens support to New-AxisRecordingProfile
    * Fixed issues with dubnet calculation in New-AxisProvisioningJob
    * Added optional credential storage to Set-AxisCredential
    * Fixed issue with New-AxisProvisioningJob where it would stall if no devices were found
## 0.4.1
    * Fixed issue with Format-AxisSDCard where it ignored the second SD card on P3737 and P3719
    * Fixed issue with Get-AxisSDCardStatus where it ignored the second SD card on P3737 and P3719
    * Fixed issue with Get-AxisDeviceInfo where it would not work against older cameras
    * Fixed issue with Enable-AxisDNSUpdate where it would not autopopulate the DNS name on older cameras
## 0.4.0
    * Fixed issue connecting to cameras via HTTP
    * Fixed issue with Format-AxisSDCard showing progress when -Wait is not specified
    * Fixed issue with New-AxisProvisioningJob where it would not return error information.
    * Fixed issue with New-AxisProvisioningJob where it would not clear screen on final print.
    * Fixed issue with New-AxisProvisioningJob where IP was not provided to provisioning process.
    * Fixed issue with New-AxisProvisioningJob where it did not check for FirmwareFolder before run
    * Fixed issue with New-AxisProvisioningJob where incremental progress was not reported.
## 0.3.1
    * Fixed issue with New-AxisProvisioningJob not functioning properly.
## 0.3.0
    * Added New-AxisProvisioningJob
    * Bug fixes
## 0.2.0
    * Further Bug fixes and readyment for inistal release
## 0.1.1 
    * Fixed issues with port from inital script
## 0.1.0
    * First Release
    * May be buggy, but shouldn't break anything as all cmdlets only connect to things.
'@
        }
    }
}