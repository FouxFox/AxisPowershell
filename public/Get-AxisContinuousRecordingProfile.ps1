<#
.SYNOPSIS
Retrieves the recording profiles for an Axis device.

.DESCRIPTION
The Get-AxisContinuousRecordingProfiles function retrieves the recording profiles for a specified Axis device.
Each recording profile represents a recording destination and parameters for the recording.
These profiles are independent of the Stream profiles and are used for recording video to the SD Card.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisContinuousRecordingProfiles -Device "192.168.1.100"

id Disk    videocodec
-- ----    ----------
10 SD_DISK h265

#>
function Get-AxisContinuousRecordingProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/record/continuous/listconfiguration.cgi"
    }
    $result = (Invoke-AxisWebApi @Param).root.continuousrecordingconfigurations.continuousrecordingconfiguration

    ForEach ($streamProfile in $result) {
        $ProfileParameters = [ordered]@{
            id =   $streamProfile.profile
            Disk = $streamProfile.diskid
        }
        ForEach ($item in $streamProfile.options.Split('&')) {
            $ProfileParameters.Add($item.Split('=')[0],$item.Split('=')[1])
        }

        if(!$ProfileParameters.Contains('camera')) {
            $ProfileParameters.Add('camera',1)
        }
        
        [pscustomobject]$ProfileParameters
    }
}