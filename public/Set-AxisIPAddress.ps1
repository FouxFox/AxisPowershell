<#
.SYNOPSIS
Sets the IP address configuration for an Axis device.

.DESCRIPTION
The Set-AxisIPAddress function is used to configure the IP address settings for an Axis device. It supports both DHCP and static IP address configurations (See Note).

.PARAMETER Device
Specifies the name or IP address of the Axis device.

.PARAMETER DHCP
Indicates whether to configure the device to use DHCP for obtaining an IP address.

.EXAMPLE
Set-AxisIPAddress -Device "192.168.0.100" -DHCP
Configures the Axis device with the IP address 192.168.0.100 and enables DHCP for obtaining the IP address.

.NOTES
Currently only supports DHCP

#>
function Set-AxisIPAddress {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$DHCP
    )

    if($DHCP) {
        $Param = @{
            Device = $Device
            Path = "/axis-cgi/param.cgi?action=update&Network.BootProto=dhcp"
        }
        Invoke-AxisWebApi @Param
    }
    else {
        ThrowError "Not Implemented"
    }
}