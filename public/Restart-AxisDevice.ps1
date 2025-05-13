<#
.SYNOPSIS
Restarts an Axis device.

.DESCRIPTION
The Restart-AxisDevice function is used to restart an Axis device.

.PARAMETER Device
Specifies the name or IP address of the Axis device to restart.

.EXAMPLE
Restart-AxisDevice -Device "192.168.1.100"
Restarts the Axis device with the IP address "192.168.1.100".
#>
function Restart-AxisDevice {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/restart.cgi"
    }
    $null = Invoke-AxisWebAPI @Param
}