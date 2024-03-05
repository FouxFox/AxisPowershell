<#
.SYNOPSIS
Deletes a recording profile on an Axis device.

.DESCRIPTION
The Remove-AxisRecordingProfile function deletes a recording profile on the specified Axis device.
Each recording profile represents a recording destination and parameters for the recording.
These profiles are independent of the Stream profiles and are used for recording video to the SD Card.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER ProfileId
The ID of the profile to remove.
This can be found using Get-AxisRecordingProfile.

.EXAMPLE
Get-AxisRecordingProfile -Device 192.168.1.100

id Disk    videocodec
-- ----    ----------
10 SD_DISK h265

Remove-AxisRecordingProfile -Device 192.168.1.100 -ProfileId 10

.NOTES
Removes recording profile but does not set Properties.LocalStorage.NbrOfContinuousRecordingProfiles to 0 for some reason

#>
function Remove-AxisRecordingProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$true)]
        [String]$ProfileId
    )

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/record/continuous/removeconfiguration.cgi?profile=$ProfileId"
    }
    $result = Invoke-AxisWebApi @Param

    if($result.root.remove.result -eq 'ERROR') {
        Throw "Could not remove profile: $($result.root.remove.errormsg)"
    }
}