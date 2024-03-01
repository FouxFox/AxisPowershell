<#
.SYNOPSIS
Retrieves device information from an Axis camera.

.DESCRIPTION
The Get-AxisDeviceInfo function retrieves device information from an Axis camera using the Axis web API.

.PARAMETER Device
Specifies the IP address or hostname of the Axis camera.

.EXAMPLE
Get-AxisDeviceInfo -Device "192.168.1.100"

Architecture    : aarch64
ProdNbr         : M3085-V
HardwareID      : 932.4
ProdFullName    : AXIS M3085-V Network Camera
Version         : 11.7.61
ProdType        : Network Camera
SocSerialNumber : 7F57A5E6-92BEEB5F-47BD4C3A-E292A028
Soc             : Ambarella CV25
Brand           : AXIS
WebURL          : http://www.axis.com
ProdVariant     :
SerialNumber    : B8A44F4BFED4
ProdShortName   : AXIS M3085-V
BuildDate       : Nov 15 2023 19:01

#>

function Get-AxisDeviceInfo {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/basicdeviceinfo.cgi"
        Method = "Post"
        Body = @{
            "apiVersion" = Get-AxisAPIVersion -Device $Device -API 'basic-device-info'
            "method" = "getAllProperties"
        }
    }

    return (Invoke-AxisWebApi @Param).data.propertyList
}