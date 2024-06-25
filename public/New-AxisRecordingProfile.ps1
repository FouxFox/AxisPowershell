<#
.SYNOPSIS
Creates a new recording profile for an Axis device.

.DESCRIPTION
The New-AxisRecordingProfile function creates a new recording profile for an Axis device. It allows you to specify the device and lens (optional) for which the recording profile should be created. If the lens is not specified, the function creates a recording profile for all available lenses.

.PARAMETER Device
Specifies the Axis device for which the recording profile should be created. This parameter is mandatory.

.PARAMETER StreamProfile
The Stream Profile to use. The profile must exist.

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

        [Parameter(Mandatory=$true)]
        [String]$StreamProfile,

        [Parameter(Mandatory=$false)]
        [String]$Lens
    )

    $disks = Get-AxisSDCardStatus -Device $Device
    $profiles = Get-AxisRecordingProfile -Device $Device | ? { $_.Status -eq 'OK'}

    if($disks.Status -ne 'OK' -and $disks.Status -ne 'connected') {
        Throw "SD Card is not in a valid state"
    }
    $diskCount = ($disks | Measure-Object).count

    $LensList = @($Lens)

    if(!$Lens) {
        # 1..1 will return an array with one entity
        $LensList = 1..(Get-AxisRecordingSupport -Device $Device).NumberofLenses
    }

    $URIString = '?'

    ForEach ($CurrentLens in $LensList) {
        #Check if there is an operational profile
        if($profiles.Lens -contains $CurrentLens) {
            Write-Warning "Lens $($CurrentLens): A recording profile already exists"
            continue
        }

        #Set proper SD Card
        #It is assumed only 2 SD cards will ever be in an Axis Camera
        if(
            $CurrentLens -eq 1 -or
            $CurrentLens % $diskCount -eq 0
        ) {
            $URIString += "diskid=SD_DISK&"
        } 
        else {
            $URIString += "diskid=SD_DISK2&"
        }

        #Add lens and recording parameters
        $URIString += "options=camera%3D$CurrentLens&"
        $URIString += "streamprofile%3D$StreamProfile"

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