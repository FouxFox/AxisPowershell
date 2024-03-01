<#
.SYNOPSIS
Retrieves the supported resolutions for an Axis device.

.DESCRIPTION
The Get-AxisSupportedResolutions function retrieves the supported resolutions for a specified Axis device.

.PARAMETER Device
The hostname or IP address of the Axis device.

.EXAMPLE
Get-AxisSupportedResolutions -Device "192.168.0.100"

320x240
640x480
640x360
800x600
1024x576
1024x768
1280x720
1280x960
1920x1080

.NOTES
This function only fetches the supported resolutions for the first lens on multi-lens devices.
#>
function Get-AxisSupportedResolutions {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )
    
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=listdefinitions&listformat=xmlschema&group=root.Image.*.Appearance.Resolution"
    }
    $resolutions = (Invoke-AxisWebApi @Param).parameterDefinitions.group.group.group.Where({ $_.name -eq "I0"}).group.parameter.type.enum.entry.value
    return $resolutions | Sort-Object { [int]($_.split('x')[0]) }
}