
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
        'Get-AxisRecordingProfile'
        'Get-AxisRecordingSupport'
        'Get-AxisSDCardStatus'
        'Get-AxisStorageOptions'
        'Get-AxisStreamProfiles'
        'Get-AxisSupportedResolutions'
        'Get-AxisViewStatus'
        'Get-AxisZipStreamSupport'
        'Initialize-AxisDevice'
        'New-AxisRecordingProfile'
        'Provision-AxisDevice'
        'Set-AxisCredential'
        'Set-AxisIPAddress'
        'Set-AxisServices'
        'Set-AxisStorageOptions'
    )
    VariablesToExport = "*"
    AliasesToExport = "*"
    FileList = @(
        'PSModule.psm1'
    )
    RequiredModules = @()
    HelpInfoURI = 'https://github.com/AbelFox/SPMTools/blob/master/README.md'
    ModuleVersion = '0.1.0'
    PrivateData = @{
        PSData = @{
            Tags = @(
                'ManagedServiceProvider'
                'Windows'
            )
            IsPrerelease = $true
            ReleaseNotes = @'    
    ## 0.1
    * First Release
    * May be buggy, but shouldn't break anything as all cmdlets only connect to things.
'@
        }
    }
}