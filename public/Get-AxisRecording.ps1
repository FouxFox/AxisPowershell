<#
.SYNOPSIS
Retrieves a list of recordings from an Axis device within a specified time range.

.DESCRIPTION
The Get-AxisRecording function retrieves recordings from an Axis device based on the specified parameters. 

.PARAMETER Device
The Hostname or IP address of the Axis device.

.PARAMETER Lens
The source lens for the recordings.
If not specified, all lenses are included.

.PARAMETER MaxResults
The maximum number of recordings to retrieve. Optional.

.PARAMETER StartTime
The start time of the recording range.

.PARAMETER StopTime
The stop time of the recording range.

.PARAMETER ThrowErrorOnTimeDifference
Specifies whether to throw an error if the time difference between the device and the current time is greater than 60 seconds. Optional.

.EXAMPLE
Get-AxisRecording -Device 192.168.1.100 -StartTimeUTC '8/29/2024 06:44:35' -StopTimeUTC '8/29/2024 15:44:35'

This example retrieves all recordings within the specified time period using the UTC timezone.

.NOTES
This function checks the time difference between the device and the current time and will warning if the difference is greater than 60 seconds.
#>
function Get-AxisRecording {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter()]
        [String]$Lens,

        [Parameter()]
        [int]$MaxResults,

        [Parameter(Mandatory)]
        [DateTime]$StartTimeUTC,

        [Parameter(Mandatory)]
        [DateTime]$StopTimeUTC,

        [Parameter(DontShow)]
        [Switch]$ThrowErrorOnTimeDifference
    )

    $DeviceTime = Get-AxisDate -Device $Device
    $DeviceSupportsTimeCheck = $DeviceTime.OffsetFromCurrent -ne 'N/A'

    if($DeviceSupportsTimeCheck -and ([Math]::Abs($DeviceTime.OffsetFromCurrent) -gt 60)) {
        if($ThrowErrorOnTimeDifference) {
            throw "The time difference between the device and the current time is greater than 60 seconds."
        }
        Write-Warning "The time difference between the device and the current time is greater than 60 seconds."
    }

    $DateTimeFormat = "yyyy-MM-ddThh:mm:ss"

    $begin = $StartTimeUTC.ToString($DateTimeFormat)
    $end = $StopTimeUTC.ToString($DateTimeFormat)
    
    #I am of the opinion that people can convert time on their own.
    <#
    if($StartTime.Kind -eq 'Local') {
        $begin = $StartTime.ToUniversalTime().ToString($DateTimeFormat)
    }

    if($StopTime.Kind -ne 'Local') {
        $end = $StopTime.ToUniversalTime().ToString($DateTimeFormat)
    }
    #>

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/record/list.cgi?starttime=$begin&stoptime=$end"
    }
    if($Lens) {
        $Param.Path += "&source=$Lens"
    }
    if($MaxResults) {
        $Param.Path += "&maxnumberofresults=$MaxResults"
    }
    $result = (Invoke-axiswebApi @Param).root.recordings
    
    if($result.numberOfRecordings -eq 0) {
        Write-Warning "No recordings found for the specified time range."
        return
    }

    return $result.recording
}