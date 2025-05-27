<#
.SYNOPSIS
Sets the configuration for the AxisPowerShell module.

.DESCRIPTION
The Set-AxisPSConfig function is used to change the behavior when values are not provided.

.EXAMPLE
Get-AxisPSConfig

FirmwareFolder   LogPath                            LogEnabled
--------------   -------                            ----------
C:\AxisFirmware\ C:\ProgramData\AxisPowershell\Log\      False

#>
function Get-AxisPSConfig {
    [cmdletbinding()]
    Param()
    
    [pscustomobject]@{
        FirmwareFolder = $Config.FirmwareFolder
        DNSSuffix = $Config.DNSSuffix
        ProvisioningSnapshotPath = $Config.ProvisioningSnapshotPath
        DefaultEdgeRecordingParameters = $Config.RecordingParams
        LogPath = $Config.LogPath
        LogEnabled = $Config.LogEnabled
    }
}