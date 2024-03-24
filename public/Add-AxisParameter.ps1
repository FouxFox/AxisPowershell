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
