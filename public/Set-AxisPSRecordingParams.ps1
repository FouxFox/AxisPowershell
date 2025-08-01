<#
.SYNOPSIS
Sets recording parameters for a specific model or the default configuration.

.DESCRIPTION
The Set-AxisPSRecordingParams function allows you to configure recording parameters for a specific product model or set default parameters. 
These parameters will then be used by the New-AxisStreamProfile when no parameters are specified.

.PARAMETER Default
Specifies that the default recording parameters should be set.

.PARAMETER ProdNbr
Specifies the product number of the model for which the recording parameters should be set. 
Full model numbers, such as P3738-PLVE, will be generalized to P3738.

.PARAMETER Parameters
Specifies the recording parameters to be set.

.EXAMPLE
Set-AxisPSRecordingParams -Default -Parameters "videocodec=h265&resolution=1280x720&fps=30"

.EXAMPLE
Set-AxisPSRecordingParams -ProdNbr M3085 -Parameters "videocodec=h265&resolution=1920x1080&fps=15"

.NOTES
This function is meant to streamline provisioning by limiting the amount of times that parameters need to be specified and carrying configurations across sessions.
To specify the model number, copy the value from Get-AxisDeviceInfo
#>
function Set-AxisPSRecordingParams {
    [cmdletbinding(DefaultParameterSetName='ByModel')]
    Param(
        [Parameter(ParameterSetName='DefaultModel',Mandatory)]
        [Switch]$Default,

        [Parameter(ParameterSetName='ByModel',Mandatory)]
        [String]$ProdNbr,

        [Parameter(ParameterSetName='ByModel',Mandatory)]
        [Parameter(ParameterSetName='DefaultModel',Mandatory)]
        [String]$Parameters
    )

    #Strip tail end of ProdNbr to generalize model
    $Model = $ProdNbr.Split('-')[0]

    if($Default) {
        $Config.RecordingParams.Default = $Parameters
        return
    }

    if(!$Config.RecordingParams.ContainsKey($Model)) {
        $Config.RecordingParams.Add($Model, $false)
    }
    $Config.RecordingParams.$Model = $Parameters

    Write-ModuleConfiguration
}