<#
.SYNOPSIS
Sets the configuration for the AxisPowerShell module.

.DESCRIPTION
The Set-AxisPSFactoryConfig function is used to Change the behavior when values are not provided.

.PARAMETER FirmwareFolder
Specifies the path to the firmware folder.

.EXAMPLE
Set-AxisPSFactoryConfig -FirmwareFolder "C:\Firmware"

This example sets the firmware folder path to "C:\Firmware".

#>
function Set-AxisPSFactoryConfig {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$FirmwareFolder
    )

    $Config.FirmwareFolder = $FirmwareFolder
    Write-ModuleConfiguration
}