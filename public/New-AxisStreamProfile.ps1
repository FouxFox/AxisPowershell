<#
.SYNOPSIS
Creates a new stream profile for an Axis device.

.DESCRIPTION
The New-AxisStreamProfile function creates a new stream profile for an Axis device. It allows you to specify the device, name, description, and parameters for the stream profile.

.PARAMETER Device
The Axis device for which the stream profile is created.

.PARAMETER Name
The name of the stream profile.

.PARAMETER Description
The description of the stream profile. 
If left empty, the description will be set to an empty string.

.PARAMETER Parameters
The parameters for the stream profile.
If left empty, the parameters will be set to the values defined in the AxisPowershell configuration file.
See Get-AxisPSRecordingParams for more information on the parameters.

.EXAMPLE
New-AxisStreamProfile -Device "192.168.0.1" -Name "Profile1" -Description "Profile 1" -Parameters "videocodec=h264&resolution=1920x1080"

This example creates a new stream profile named "Profile1" with the description "Profile 1" and the parameters "videocodec=h264&resolution=1920x1080" for the Axis device "AXIS-001".
#>
function New-AxisStreamProfile {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$Device,

        [Parameter(Mandatory)]
        [String]$Name,

        [Parameter()]
        [String]$Description='',

        [Parameter()]
        [String]$Parameters
    )
    
    $streamParameters = $Parameters
    $Model = (Get-AxisDeviceInfo -Device $Device).ProdNbr.Split('-')[0]
    $SupportedCodecs = (Get-AxisRecordingSupport -Device $Device).SupportedCodecs

    # If no parameters are provided, search the configuration for the model-specific parameters
    # If no model-specific parameters are found, use the default parameters
    if(!$Parameters) {
        if($Config.RecordingParams.ContainsKey($Model)) {
            $streamParameters = "$($Config.RecordingParams.$Model)"
        } 
        else {
            $streamParameters = "$($Config.RecordingParams.Default)"
        }
    }

    # runs a regex to check if videocodec is one of the supported codecs
    if(
        $streamParameters.contains('videocodec') -and
        $streamParameters -notmatch "videocodec=($($SupportedCodecs.Replace(',','|')))&"
    ) {
        Throw "Codec not supported. Please use a supported codec." 
    }

    #Stream Parameters do not need HTML encoding
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/streamprofile.cgi"
        Method = "Post"
        Body = @{
            "apiVersion" = '1.0'
            "method" = "create"
            "params" = @{
                "streamProfile" = @(@{
                    "name" = $Name
                    "description" = $Description
                    "parameters" = $streamParameters
                
                })
            }
        }
    }

    $result = Invoke-AxisWebApi @Param

    if($result.error) {
        Write-Warning $result.error.message
    }
}