
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
        'Disable-AxisUnusedViews'
        'Enable-AxisDNSUpdate'
        'Format-AxisSDCard'
        'Get-AxisAction'
        'Get-AxisContinuousRecordingProfile'
        'Get-AxisDeviceInfo'
        'Get-AxisNetworkInfo'
        'Get-AxisParameter'
        'Get-AxisPSConfig'
        'Get-AxisRecordingProfile'
        'Get-AxisRecordingSupport'
        'Get-AxisSDCardStatus'
        'Get-AxisSnapshot'
        'Get-AxisStorageOptions'
        'Get-AxisStreamProfiles'
        'Get-AxisSupportedResolutions'
        'Get-AxisViewStatus'
        'Initialize-AxisDevice'
        'Invoke-AxisWebAPI'
        'New-AxisProvisioningJob'
        'New-AxisRecordingProfile'
        'Optimize-AxisRecordingProfiles'
        'Remove-AxisAction'
        'Remove-AxisParameter'
        'Remove-AxisRecordingProfile'
        'Reset-AxisDevice'
        'Restart-AxisDevice'
        'Set-AxisCredential'
        'Set-AxisIPAddress'
        'Set-AxisPSConfig'
        'Set-AxisServices'
        'Set-AxisStorageOptions'
        'Update-AxisDevice'
        'Update-AxisParameter'
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
    ModuleVersion = '0.7.1'
    PrivateData = @{
        PSData = @{
            Tags = @(
                'ManagedServiceProvider'
                'Windows'
            )
            IsPrerelease = $true
            ReleaseNotes = @'
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