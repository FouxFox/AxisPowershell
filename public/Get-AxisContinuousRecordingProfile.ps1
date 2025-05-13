<#
.SYNOPSIS
Retrieves the continuous recording profiles for an Axis device.

.DESCRIPTION
The Get-AxisContinuousRecordingProfile function retrieves the continuous recording profiles for a specified Axis device. 

.PARAMETER Device
The IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisContinuousRecordingProfile -Device "192.168.1.100"

id Disk     camera
-- ----     ------
24 SD_DISK2 3
23 SD_DISK  2
25 SD_DISK  4
22 SD_DISK  1

#>
function Get-AxisContinuousRecordingProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
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
        
        [pscustomobject]$ProfileParameters | Sort-Object camera
    }
}