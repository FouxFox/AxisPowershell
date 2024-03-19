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
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [String]$FirmwareFolder,

        [Parameter(Mandatory=$false)]
        [String]$LogPath,

        [Parameter(Mandatory=$false)]
        [Switch]$EnableLogging,

        [Parameter(Mandatory=$false)]
        [Switch]$DisableLogging
    )
    
    if($FirmwareFolder) {
        $Config.FirmwareFolder = $FirmwareFolder
    }
    if($LogDir) {
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