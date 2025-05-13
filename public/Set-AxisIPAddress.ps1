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
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [Switch]$DHCP
    )

    if($DHCP) {
        Update-AxisParameter -Device $Device -Parameter "Network.BootProto" -Value "dhcp"
    }
    else {
        ThrowError "Not Implemented"
    }
}