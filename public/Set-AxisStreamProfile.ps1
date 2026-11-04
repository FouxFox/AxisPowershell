<#
.SYNOPSIS
Sets values on a stream profile.

.DESCRIPTION
The Set-AxisStreamProfile function is used to set values on an existing stream profile.

.PARAMETER Device
The Axis device for which the stream profile needs to be set.

.PARAMETER Name
The name of the stream profile to be modified.

.PARAMETER NewName
(Optional) The new name for the stream profile.

.PARAMETER Description
(Optional) The new description for the stream profile.

.PARAMETER Parameters
(Optional) The new parameters for the stream profile.

.EXAMPLE
Set-AxisStreamProfile -Device "AxisDevice1" -Name "Profile1" -NewName "Profile2" -Parameters "videocodec=h264&resolution=1920x1080"

This example renames the profile to "Profile2", and updates the parameters to "videocodec=h264&resolution=1920x1080"".
#>
function Set-AxisStreamProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter()]
        [String]$NewName,

        [Parameter()]
        [String]$Description,

        [Parameter()]
        [String]$Parameters
    )

    if(!$NewName -and !$Description -and !$Parameters) {
        Throw "At least one of the parameters NewName, Description or Parameters must be specified"
    }

    if($Description -or $Parameters) {
        $StreamProfile = @{
            "name" = $Name
        }
        if($Description) {
            $StreamProfile.Add("description",$Description)
        }
        if($Parameters) {
            $StreamProfile.Add("parameters",$Parameters)
        }

        $Param = @{
            Device = $Device
            Path = "/axis-cgi/streamprofile.cgi"
            Method = "Post"
            Body = @{
                "apiVersion" = '1.0'
                "method" = "update"
                "params" = @{
                    "streamProfile" = @($StreamProfile)
                }
            }
        }

        $result = Invoke-AxisWebApi @Param

        if($result.error) {
            Write-Warning $result.error.message
        }
    }

    #The stream profile API has no rename method, so recreate the profile under the new name
    if($NewName) {
        $Existing = Get-AxisStreamProfile -Device $Device -Name $Name
        if(!$Existing) {
            Throw "Stream profile '$Name' not found"
        }
        Remove-AxisStreamProfile -Device $Device -Name $Name
        New-AxisStreamProfile -Device $Device -Name $NewName -Description $Existing.description -Parameters $Existing.parameters
    }
}
