function Set-AxisServices {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device,

        [Parameter(Mandatory=$false)]
        [Switch]$Bonjour=$false,

        [Parameter(Mandatory=$false)]
        [Switch]$SSH=$false,

        [Parameter(Mandatory=$false)]
        [Switch]$UPnP=$false,

        [Parameter(Mandatory=$false)]
        [Switch]$WSDiscovery=$false
    )

    $URIString = ''
    $URIString += "&Network.Bonjour.Enabled=$(if($Bonjour) {'yes'} else {'no'})"
    $URIString += "&Network.SSH.Enabled=$(if($SSH) {'yes'} else {'no'})"
    $URIString += "&Network.UPnP.Enabled=$(if($UPnP) {'yes'} else {'no'})"
    $URIString += "&WebService.DiscoveryMode.Discoverable=$(if($WSDiscovery) {'yes'} else {'no'})"


    $Param = @{
            Device = $Device
            Path = "/axis-cgi/param.cgi?action=update$($URIString)"
        }
    Invoke-AxisWebApi @Param
}