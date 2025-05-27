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
        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$FirmwareFolder,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$LogPath,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$ProvisioningSnapshotPath,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$DNSSuffix,

        [Parameter(ParameterSetName='LoggingOn')]
        [Parameter(ParameterSetName='LoggingOff')]
        [String]$DefaultEdgeRecordingParameters,

        [Parameter(ParameterSetName='LoggingOn')]
        [Switch]$EnableLogging,

        [Parameter(ParameterSetName='LoggingOff')]
        [Switch]$DisableLogging
    )
    
    if($FirmwareFolder) {
        $Config.FirmwareFolder = $FirmwareFolder
    }
    if($LogPath) {
        $Config.LogPath = $LogPath
    }
    if ($ProvisioningSnapshotPath) {
        $Config.ProvisioningSnapshotPath = $ProvisioningSnapshotPath
    }
    if ($DefaultEdgeRecordingParameters) {
        $Config.RecordingParams = $DefaultEdgeRecordingParameters
    }
    if ($DNSSuffix) {
        $Config.DNSSuffix = $DNSSuffix
    }
    if($EnableLogging) {
        $Config.LogEnabled = $true
    }
    if ($DisableLogging) {
        $Config.LogEnabled = $false
    }

    Write-ModuleConfiguration
}