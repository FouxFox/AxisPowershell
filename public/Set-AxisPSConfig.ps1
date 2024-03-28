<#
.SYNOPSIS
Sets the configuration for the AxisPowerShell module.

.DESCRIPTION
The Set-AxisPSConfig function is used to change the behavior when values are not provided.

.PARAMETER FirmwareFolder
Specifies the path to the firmware folder.

.EXAMPLE
Set-AxisPSConfig -FirmwareFolder "C:\Firmware"

This example sets the firmware folder path to "C:\Firmware".

#>
function Set-AxisPSConfig {
    [cmdletbinding(DefaultParameterSetName='LoggingOn')]
    Param(
        [Parameter(Mandatory=$false, ParameterSetName='LoggingOn')]
        [Parameter(Mandatory=$false, ParameterSetName='LoggingOff')]
        [String]$FirmwareFolder,

        [Parameter(Mandatory=$false, ParameterSetName='LoggingOn')]
        [Parameter(Mandatory=$false, ParameterSetName='LoggingOff')]
        [String]$LogPath,

        [Parameter(Mandatory=$false, ParameterSetName='LoggingOn')]
        [Switch]$EnableLogging,

        [Parameter(Mandatory=$false, ParameterSetName='LoggingOff')]
        [Switch]$DisableLogging
    )
    
    if($FirmwareFolder) {
        $Config.FirmwareFolder = $FirmwareFolder
    }
    if($LogPath) {
        $Config.LogPath = $LogPath
    }
    if($EnableLogging) {
        $Config.LogEnabled = $true
    }
    if ($DisableLogging) {
        $Config.LogEnabled = $false
    }

    Write-ModuleConfiguration
}