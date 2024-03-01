<#
.SYNOPSIS
Retrieves the stream profiles for an Axis device.

.DESCRIPTION
The Get-AxisStreamProfiles function retrieves the stream profiles for a specified Axis device.
These profiles are independent of the Recording profiles and are used for streaming video to the NVR.

.PARAMETER Device
The IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisStreamProfiles -Device "192.168.1.100"

Name             : ConfigToolProfile
Description      :
videocodec       : h265
resolution       : 1280x720
fps              : 10
compression      : 70
videobitratemode : mbr
videomaxbitrate  : 768
#>
function Get-AxisStreamProfiles {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/streamprofile.cgi"
        Body = @{
            "apiVersion" = "1.0"
            "method" = "list"
            "params" = @{
                "streamProfileName" = @()
            }
        }
    }

    $result = (Invoke-AxisWebApi @Param).data.streamProfile

    ForEach ($streamProfile in $result) {
        $ProfileParameters = [ordered]@{
            Name =        $streamProfile.name
            Description = $streamProfile.description
        }
        ForEach ($item in $streamProfile.parameters.Split('&')) {
            $ProfileParameters.Add($item.Split('=')[0],$item.Split('=')[1])
        }
        
        [pscustomobject]$ProfileParameters
    }
}