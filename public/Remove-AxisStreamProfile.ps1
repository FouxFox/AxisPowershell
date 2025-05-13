<#
.SYNOPSIS
Removes stream profiles from a specified device.

.DESCRIPTION
The Remove-AxisStreamProfile function removes one or more Axis stream profiles from a specified device.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device from which the stream profiles should be removed.

.PARAMETER Name
Specifies the name or names of the stream profiles to be removed. You can specify multiple names by providing an array of strings.

.EXAMPLE
Remove-AxisStreamProfile -Device "192.168.1.100" -Name "Profile1"

Removes the stream profile named "Profile1" from the Axis device with the IP address "192.168.1.100".
#>
function Remove-AxisStreamProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String[]]$Name
    )

    $profiles = @()
    ForEach ($item in $Name) {
        $profiles += @{
            "name" = $item
        }
    }

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/streamprofile.cgi"
        Method = "Post"
        Body = @{
            "apiVersion" = '1.0'
            "method" = "remove"
            "params" = @{
                "streamProfileName" = $profiles
            }
        }
    }

    $result = Invoke-AxisWebApi @Param

    if($result.error) {
        Write-Warning $result.error.message
    }
}