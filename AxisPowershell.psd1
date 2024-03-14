
@{
    RootModule = 'PSModule.psm1'
    GUID = '072c1e6d-39ea-4620-88b4-52d3a1156541'
    Author = 'Matt Small'
    Copyright = '(c) Matt Small. All rights reserved.'
    Description = "A module for managing Axis devices."
    PowerShellVersion = '3.0'
    #FormatsToProcess = ''
    FunctionsToExport = @(
        'Disable-AxisUnusedViews'
        'Enable-AxisDNSUpdate'
        'Format-AxisSDCard'
        'Get-AxisDeviceInfo'
        'Get-AxisNetworkInfo'
        'Get-AxisPSRecordingProfile'
        'Get-AxisRecordingProfile'
        'Get-AxisRecordingSupport'
        'Get-AxisSDCardStatus'
        'Get-AxisStorageOptions'
        'Get-AxisStreamProfiles'
        'Get-AxisSupportedResolutions'
        'Get-AxisViewStatus'
        'Initialize-AxisDevice'
        'New-AxisRecordingProfile'
        'Provision-AxisDevice'
        'Remove-AxisRecordingProfile'
        'Set-AxisCredential'
        'Set-AxisIPAddress'
        'Set-AxisServices'
        'Set-AxisStorageOptions'
        'Update-AxisDevice'
        'Reset-AxisDevice'
        'Set-AxisPSFactoryConfig'
        'New-AxisProvisioningJob'
    )
    VariablesToExport = "*"
    AliasesToExport = "*"
    FileList = @(
        'PSModule.psm1'
    )
    RequiredModules = @()
    HelpInfoURI = ''
    ModuleVersion = '0.4.1'
    PrivateData = @{
        PSData = @{
            Tags = @(
                'ManagedServiceProvider'
                'Windows'
            )
            IsPrerelease = $true
            ReleaseNotes = @'
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