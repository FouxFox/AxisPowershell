<#
.SYNOPSIS
Retrieves the recording profiles for an Axis device.

.DESCRIPTION
The Get-AxisRecordingProfile function retrieves the recording profiles for a specified Axis device.
It checks for both continuous recording profiles and action rules associated with each lens of the device. 
It returns an object containing information about the status, type, disk location, and any errors for each lens.

.PARAMETER Device
The name or IP address of the Axis device.

.EXAMPLE
Get-AxisRecordingProfile -Device "192.168.1.100"

Lens Status Type       Disk     Error
---- ------ ----       ----     -----
   1 OK     Continuous SD_DISK  N/A
   2 OK     Continuous SD_DISK  N/A  
   3 OK     Continuous SD_DISK2 N/A
   4 OK     Continuous SD_DISK  N/A
#>
function Get-AxisRecordingProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )
    
    $LensCount = (Get-AxisViewStatus -RemoveCombinedViews -Device $Device).count
    $SingleLens = $LensCount -eq 1
    $cProfiles = Get-AxisContinuousRecordingProfile -Device $Device
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
                Status  = 'Warning'
                Type    = 'N/A'
                Disk    = 'N/A'
                Error   = 'No Profile Exists'
            }
        }
    }

    return $output
}