<#
.SYNOPSIS
Updates the parameter(s) of an Axis device.

.DESCRIPTION
The Update-AxisParameter function is used to update the parameter(s) of an Axis device.
It supports updating a single parameter or multiple parameters at once.

.PARAMETER Device
Specifies the hostname or IP address of the Axis device.

.PARAMETER Parameter
Specifies the name of the parameter to update.

.PARAMETER Value
Specifies the new value for the parameter.

.PARAMETER ParameterSet
Specifies a hashtable containing the parameters and their corresponding values to update.

.EXAMPLE
Update-AxisParameter -Device "192.168.1.100" -Parameter "Brightness" -Value "50"
Updates the 'Brightness' parameter of the Axis device with the value '50'.

.EXAMPLE
Update-AxisParameter -Device "192.168.1.100" -ParameterSet @{
    "Brightness" = "50"
    "Contrast" = "75"
}
Updates the 'Brightness' and 'Contrast' parameters of the Axis device with the specified values.
#>
function Update-AxisParameter {
    [cmdletbinding(DefaultParameterSetName='Single')]
    Param(
        [Parameter(ParameterSetName='Single', Mandatory)]
        [Parameter(ParameterSetName='Multiple', Mandatory)]
        [String]$Device,

        [Parameter(ParameterSetName='Single', Mandatory)]
        [String]$Parameter,

        [Parameter(ParameterSetName='Single', Mandatory)]
        [String]$Value,

        [Parameter(ParameterSetName='Multiple', Mandatory)]
        [Hashtable]$ParameterSet
    )

    if($PSCmdlet.ParameterSetName -eq 'Single') {
        $ParameterSet = @{}
        $ParameterSet[$Parameter] = $Value
    }

    $URIString = ""
    ForEach ($p in $ParameterSet.Keys) {
        $URIString += "&$p=$([System.Web.HttpUtility]::UrlPathEncode($ParameterSet[$p]))"
    }

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=update$($URIString)"
    }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to update parameter(s)"
    }
}
