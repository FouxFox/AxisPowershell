<#
.SYNOPSIS
Sets the configuration for the AxisPowerShell module.

.DESCRIPTION
The Set-AxisPSConfig function is used to change the behavior when values are not provided.

.PARAMETER FirmwareFolder
Specifies the path to the firmware folder.

.EXAMPLE
Get-AxisPSConfig -FirmwareFolder "C:\Firmware"

This example sets the firmware folder path to "C:\Firmware".

#>
function Get-AxisPSConfig {
    [cmdletbinding()]
    Param()
    
    [pscustomobject]@{
        FirmwareFolder = $Config.FirmwareFolder
        LogPath = $Config.LogPath
        LogEnabled = $Config.LogEnabled
    }
}