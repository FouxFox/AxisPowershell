<#
.SYNOPSIS
Retrieves device information from an Axis camera.

.DESCRIPTION
The Get-AxisDeviceInfo function retrieves device information from an Axis camera using the Axis web API.

.PARAMETER Device
Specifies the IP address or hostname of the Axis camera.

.EXAMPLE
Get-AxisDeviceInfo -Device "192.168.1.100"

Architecture   : aarch64
ProdNbr        : P3719-PLE
HardwareID     : 797
ProdFullName   : AXIS P3719-PLE Network Camera
Version        : 11.7.61
ProdType       : Network Camera
Soc            : Ambarella S5
SerialNumber   : B8A44FB197BB
ProdShortName  : AXIS P3719-PLE
FWBuildDate    : Nov 15 2023 19:02
NumberofLenses : 4

#>
<#
Properties.Firmware.Version
Properties.System.SerialNumber
Brand.ProdNbr=P3268-LVE
Brand.ProdShortName
ImageSource.NbrOfSources
#>
function Get-AxisDeviceInfo {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device
    )

<#
    #This is the new way of doing it but gives crap results, so we are sticking with the old way
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/basicdeviceinfo.cgi"
        Method = "Post"
        Body = @{
            "apiVersion" = '1.0'
            "method" = "getAllProperties"
        }
    }

    return (Invoke-AxisWebApi @Param).data.propertyList
#>
    $Group = @( 
        'Properties.Firmware'
        'Properties.System'
        'Brand'
        'ImageSource'
    )
    $result = Get-AxisParameter -Device $Device -Group $Group
    
    [pscustomobject]@{
        Architecture    = $result.'Properties.System.Architecture'
        ProdNbr         = $result.'Brand.ProdNbr'
        HardwareID      = $result.'Properties.System.HardwareID'
        ProdFullName    = $result.'Brand.ProdFullName'
        Version         = $result.'Properties.Firmware.Version'
        ProdType        = $result.'Brand.ProdType'
        Soc             = $result.'Properties.System.Soc'
        SerialNumber    = $result.'Properties.System.SerialNumber'
        ProdShortName   = $result.'Brand.ProdShortName'
        FWBuildDate     = $result.'Properties.Firmware.BuildDate'
        NumberofLenses  = $result.'ImageSource.NbrOfSources'
    }
}