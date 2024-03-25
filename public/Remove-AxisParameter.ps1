<#
.SYNOPSIS
Removes parameter group(s) from an Axis device.

.DESCRIPTION
The Remove-AxisParameter function removes the specified parameter group(s) from an Axis device.

.PARAMETER Device
The hostname or IP address of the Axis device.

.PARAMETER Group
An array of parameter group names to be removed.

.EXAMPLE
Remove-AxisParameter -Device "192.168.0.100" -Group "Network", "Video"

This example removes the "Network" and "Video" parameter groups from the Axis device with the IP address "192.168.0.100".
#>

function Remove-AxisParameter {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String[]]$Group
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=remove&group=$($Group -join ',')"
    }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to remove parameter group(s)"
    }
}
