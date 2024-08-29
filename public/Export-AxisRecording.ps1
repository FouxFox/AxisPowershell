<#
.SYNOPSIS
Exports an Axis recording to a specified file path.

.DESCRIPTION
The Export-AxisRecording function exports a recording from an Axis device to a specified file path.

.PARAMETER Device
The Hostname or IP address of the Axis device.

.PARAMETER StartTime
The start time of the recording to export.

.PARAMETER StopTime
The stop time of the recording to export.

.PARAMETER FilePath
The file path where the exported recording will be saved.
A filename must be included.

.PARAMETER Format
The format in which the recording should be exported. The default format is matroska.
Most cameras only support the matroska format.

.EXAMPLE
Export-AxisRecording -Device 192.168.1.100 -StartTimeUTC "2022-01-01 00:00:00" -StopTimeUTC "2022-01-01 01:00:00" -FilePath "C:\Recordings\recording.mkv"

This example exports a recording from the Axis device that occurred between January 1, 2022, 00:00:00 and January 1, 2022, 01:00:00 in the UTC Timezone. 
The exported recording will be saved as "C:\Recordings\recording.mkv".
#>
function Export-AxisRecording {
    [cmdletbinding(
        SupportsShouldProcess = $true,
        ConfirmImpact='high'
    )]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [DateTime]$StartTimeUTC,

        [Parameter(Mandatory)]
        [DateTime]$StopTimeUTC,

        [Parameter(Mandatory)]
        [String]$FilePath,

        [Parameter()]
        [String]$Format="matroska"
    )

    if($FilePath -notmatch "\.[A-Z1-9]{3}") {
        throw "Invalid Path. Please specify a valid path with a file name and extension."
    }

    $DateTimeFormat = "yyyy-MM-ddThh:mm:ss"

    $begin = $StartTimeUTC.ToString($DateTimeFormat)
    $end = $StopTimeUTC.ToString($DateTimeFormat)

    $Param = @{
        Device = $Device
        StartTime = $begin
        StopTime = $end
        MaxResults = 1
        ThrowErrorOnTimeDifference = $true
    }

    Try {
        $Recording = Get-AxisRecording @Param
    }
    catch {
        #Time is wrong on device. Ask user if we should ignore this and continue.
        $SPDescription = "Time Difference Warning"
        $SPWarning = "Do you want to continue?"
        $SPCaption = "The time difference between the device and the current time is greater than 60 seconds."
        if(!$PSCmdlet.ShouldProcess($SPDescription,$SPWarning,$SPCaption)) {
            return
        }

        $Param.ThrowErrorOnTimeDifference = $false
        $Recording = Get-AxisRecording @Param
    }

    if($Recording) {
        $Param = @{
            Device = $Device
            Path = "/axis-cgi/record/export/exportrecording.cgi?schemaversion=1"
            OutFile = $FilePath
        }
        $Param.Path += "&recordingid=$($Recording.recordingid)"
        $Param.Path += "&diskid=$($Recording.diskid)"
        $Param.Path += "&exportformat=$Format"
        $Param.Path += "&starttime=$begin"
        $Param.Path += "&stoptime=$end"
    }
    $OldProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    Try{
        Invoke-AxisWebApi @Param
    }
    Catch {
        $ProgressPreference = $OldProgressPreference
        Throw $_
    }
}