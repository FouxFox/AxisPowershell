<#
.SYNOPSIS
Creates a new recording profile for an Axis device.

.DESCRIPTION
The New-AxisRecordingProfile function creates a new recording profile for an Axis device.
Each recording profile represents a LOCAL recording destination and parameters for the recording.

Recording Parameters are pulled from the stored client configuration.
For more information on the recording parameters, see Get-AxisPSRecordingProfile

.PARAMETER Device
The IP address or hostname of the Axis device.

.EXAMPLE
New-AxisRecordingProfile -Device "192.168.0.100"

OK!
#>
function New-AxisRecordingProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [String]$Lens
    )

    $disks = Get-AxisSDCardStatus -Device $Device

    if($disks.Status -ne 'OK') {
        Throw "SD Card is not in a valid state"
    }

    $LensList = @($Lens)

    if(!$Lens) {
        $LensList = 1..(Get-AxisRecordingSupport -Device $Device).NumberofLenses
    }

    $URIString = '?'

    ForEach ($CurrentLens in $LensList) {
        $URIString += "camera=$CurrentLens&"
        if(
            $CurrentLens -eq 1 -or
            $CurrentLens % $disks.Count -eq 0
        ) {
            $URIString += "diskid=SD_DISK&"
        } 
        else {
            $URIString += "diskid=SD_DISK2&"
        }

        $URIString += "options=$($Config.RecordingParams.Replace('=','%3D'))"

        $Param = @{
            Device = $Device
            Path = "/axis-cgi/record/continuous/addconfiguration.cgi$URIString"
        }
        $result = (Invoke-AxisWebApi @Param).root.configure.result

        if($result -ne 'OK') {
            Throw "Lens $($CurrentLens): Unable to add Continuious Recording Profile"
        }
    }
}