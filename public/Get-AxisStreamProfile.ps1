<#
.SYNOPSIS
Retrieves the stream profiles from an Axis device.

.DESCRIPTION
The Get-AxisStreamProfile function retrieves the stream profiles from an Axis device.

.PARAMETER Device
Specifies the Axis device from which to retrieve the stream profiles.

.EXAMPLE
Get-AxisStreamProfile -Device "192.168.0.100"

name              description parameters
----              ----------- ----------
ConfigToolProfile             videocodec=h265&resolution=1280x720&fps=10&compression=70&videobitratemode=mbr&videomaxbitrate=800
Recording                     videocodec=h265&videobitratemode=vbr&videozstrength=20&videozgopmode=dynamic&videozprofile=storage
#>
function Get-AxisStreamProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [String[]]$Name,

        [Parameter(Mandatory=$false)]
        [Switch]$ExpandParameters,

        [Parameter(Mandatory=$false,DontShow)]
        [Switch]$MaxProfiles
    )
    
    $profiles = @()
    if($Name) {
        ForEach ($item in $Name) {
            $profiles += @{
                "name" = $item
            }
        }
    }

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/streamprofile.cgi"
        Method = "Post"
        Body = @{
            "apiVersion" = '1.0'
            "method" = "list"
            "params" = @{
                "streamProfileName" = @()
            }
        }
    }

    $Data = (Invoke-AxisWebApi @Param).data

    if(($Data.streamProfile.Name).contains("EdgeRecording")) {
        Write-Warning '"EdgeRecording" profile already exists!'
    }

    if($MaxProfiles) {
        return $Data.maxProfiles
    }
    
    if(!$ExpandParameters) {
        return $Data.streamProfile
    }

    $Data.streamProfile | ForEach-Object {
        $ProfileParameters = [ordered]@{
            Name =        $_.name
            Description = $_.description
        }
        ForEach ($item in $_.parameters.Split('&')) {
            $ProfileParameters.Add($item.Split('=')[0],$item.Split('=')[1])
        }
        
        [pscustomobject]$ProfileParameters
    }
}