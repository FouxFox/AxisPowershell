<#
.SYNOPSIS
Retrieves the recording profiles for an Axis device.

.DESCRIPTION
The Get-AxisRecordingProfile function retrieves the recording profiles for a specified Axis device.
Each recording profile represents a recording destination and parameters for the recording.
These profiles are independent of the Stream profiles and are used for recording video to the SD Card.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisRecordingProfile -Device "192.168.1.100"

id Disk    videocodec
-- ----    ----------
10 SD_DISK h265

#>
function Get-AxisRecordingProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    $LensCount = (Get-AxisViewStatus -RemoveCombinedViews -Device $Device).count
    $SingleLens = $LensCount -eq 1
    $cProfiles = Get-AxisContinuousRecordingProfiles -Device $Device
    $Actions = Get-AxisAction -Device $Device | ? { $_.TemplateToken -eq "com.axis.action.unlimited.recording.storage" }

    #Decode Actions
    $aProfiles = @()
    ForEach ($ap in $Actions) {
        $Lens = 1 #No "camera=" in stream options defaults to 1
        if(!$SingleLens -and $ap.StreamOptions.contains('camera')) {
            $Lens = $ap.StreamOptions.subString($ap.StreamOptions.indexOf('camera=')+7,1)
        }

        $aProfiles += [PSCustomObject]@{
            ID      = $ap.ID
            camera  = $Lens
            Disk    = $ap.StorageLocation
        }
    }

    $output = @()

    ForEach ($Lens in 1..$LensCount) {
        $HasCProfile = $cProfiles.camera -contains $Lens
        $HasAProfile = $aProfiles.camera -contains $Lens

        if($HasCProfile -and $HasAProfile) {
            $output += [PSCustomObject]@{
                Lens    = $Lens
                Status  = 'Error'
                Type    = 'N/A'
                Disk    = 'N/A'
                Error   = 'Continuious Profiles and Action rules found for this lens'
            }
        }
        elseif($HasCProfile) {
            $cProfile = $cProfiles | ? { $_.camera -eq $Lens }
            $output += [PSCustomObject]@{
                Lens    = $Lens
                Status  = 'OK'
                Type    = 'Continuous'
                Disk    = $cProfile.Disk
                Error   = 'N/A'
            }
        }
        elseif($HasAProfile) {
            $aProfile = $aProfiles | ? { $_.camera -eq $Lens }
            $output += [PSCustomObject]@{
                Lens    = $Lens
                Status  = 'Warning'
                Type    = 'Action'
                Disk    = $aProfile.Disk
                Error   = 'It is recomended to use Continuous Profiles'
            }
        }
        else {
            $output += [PSCustomObject]@{
                Lens    = $Lens
                Status  = 'Error'
                Type    = 'Error'
                Disk    = 'N/A'
                Error   = 'No Profile Exists'
            }
        }
    }

    return $output
}