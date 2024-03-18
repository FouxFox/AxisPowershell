<#
.SYNOPSIS
Creates a new recording profile for an Axis device.

.DESCRIPTION
The New-AxisRecordingProfile function creates a new recording profile for an Axis device. It allows you to specify the device and lens (optional) for which the recording profile should be created. If the lens is not specified, the function creates a recording profile for all available lenses.

.PARAMETER Device
Specifies the Axis device for which the recording profile should be created. This parameter is mandatory.

.PARAMETER Lens
Specifies the numeric lens for which the recording profile should be created. 
This parameter is optional. 
If not specified, the function creates a recording profile for all available lenses.

.EXAMPLE
New-AxisRecordingProfile -Device "192.168.1.100" -Lens 1

.EXAMPLE
New-AxisRecordingProfile -Device "192.168.1.100"
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
        if(
            $CurrentLens -eq 1 -or
            $CurrentLens % $disks.Count -eq 0
        ) {
            $URIString += "diskid=SD_DISK&"
        } 
        else {
            $URIString += "diskid=SD_DISK2&"
        }

        $URIString += "options=camera%3D$CurrentLens&"
        $URIString += "$($Config.RecordingParams.Replace('=','%3D'))"

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