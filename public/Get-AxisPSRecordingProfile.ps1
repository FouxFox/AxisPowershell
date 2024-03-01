<#
.SYNOPSIS
Retrieves the recording profile parameters for Axis PowerShell module.

.DESCRIPTION
The Get-AxisPSRecordingProfile function retrieves the recording profile parameters for the Axis PowerShell module.
These parameters are used when New-AxisRecordingProfile is called.

.EXAMPLE
Get-AxisPSRecordingProfile

#>
function Get-AxisPSRecordingProfile {
    [cmdletbinding()]
    Param()
    
    <#
    videocodec         : h265
    fps                : 30
    compression        : 30
    videozstrength     : 20
    videozgopmode      : dynamic
    videozmaxgoplength : 1023
    videozprofile      : storage
    #>
    $translationList = @{
        'videocodec' = 'Video Codec'
        'fps' = 'FPS'
        'compression' = 'Compression Strength'
        'videozstrength' = 'ZipStream Strength'
        'videozgopmode' = 'ZipStream GOP Mode'
        'videozmaxgoplength' = 'GOP Max Length'
        'videozprofile' = 'ZipStream Profile'
    }

    $ProfileParameters = [ordered]@{}
    ForEach ($item in $Config.RecordingParams.Split('&')) {
        $Parameter = $item.Split('=')[0]
        $value = $item.Split('=')[1]
        
        #Translate values we've accounted for
        if($translationList.Contains($Parameter)) {
            $Parameter = $translationList[$Parameter]
        }

        $ProfileParameters.Add($Parameter,$value)
    }
        
    return [pscustomobject]$ProfileParameters
}