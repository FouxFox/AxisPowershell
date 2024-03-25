<#
.SYNOPSIS
Adds a parameter to an Axis device.

.DESCRIPTION
The Add-AxisParameter function adds a parameter to an Axis device. It supports adding a single parameter or multiple parameters at once.

.PARAMETER Device
Specifies the hostname or IP address of the Axis device.

.PARAMETER Template
Specifies the template name.

.PARAMETER Group
Specifies the group name.

.PARAMETER Parameter
Specifies the parameter name.

.PARAMETER Value
Specifies the value of the parameter.

.PARAMETER ParameterSet
Specifies a hashtable containing multiple parameters and their values. This parameter is used when adding multiple parameters at once.

.EXAMPLE
Add-AxisParameter -Device "192.168.0.100" -Template "Template1" -Group "Group1" -Parameter "Param1" -Value "Value1"
Adds a single parameter to the Axis device with the specified values.

.EXAMPLE
$parameters = @{
    "Param1" = "Value1"
    "Param2" = "Value2"
}
Add-AxisParameter -Device "192.168.0.100" -Template "Template1" -Group "Group1" -ParameterSet $parameters
Adds multiple parameters to the Axis device using a hashtable.
#>
function Add-AxisParameter {
    [cmdletbinding(DefaultParameterSetName='Single')]
    Param(
        [Parameter(Mandatory=$true, ParameterSetName='Single')]
        [Parameter(Mandatory=$true, ParameterSetName='Multiple')]
        [String]$Device,

        [Parameter(Mandatory=$true, ParameterSetName='Single')]
        [Parameter(Mandatory=$true, ParameterSetName='Multiple')]
        [String]$Template,

        [Parameter(Mandatory=$true, ParameterSetName='Single')]
        [Parameter(Mandatory=$true, ParameterSetName='Multiple')]
        [String]$Group,

        [Parameter(Mandatory=$true, ParameterSetName='Single')]
        [String]$Parameter,

        [Parameter(Mandatory=$true, ParameterSetName='Single')]
        [String]$Value,

        [Parameter(Mandatory=$true, ParameterSetName='Multiple')]
        [Hashtable]$ParameterSet
    )

    if($PSCmdlet.ParameterSetName -eq 'Single') {
        $ParameterSet = @{}
        $ParameterSet[$Parameter] = $Value
    }

    $URIString = "&template=$Template&group=$Group"
    ForEach ($p in $ParameterSet.Keys) {
        $URIString += "&$p=$([System.Web.HttpUtility]::UrlPathEncode($ParameterSet[$p]))"
    }

    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=add$($URIString)"
    }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to add parameter(s)"
    }
}
