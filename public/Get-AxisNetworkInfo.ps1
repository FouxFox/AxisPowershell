function Get-AxisNetworkInfo {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    #Standard Post method did not work even on current cameras. This was somehow better
    $Param = @{
        Device = $Device
        Path = "/axis-cgi/param.cgi?action=list&group=Network,WebService.DiscoveryMode.Discoverable"
    }

    $result = (Invoke-AxisWebApi @Param).replace("root.",'')
    #Invoke-AxisWebApi Device 10.49.0.2 -Path "/axis-cgi/network_settings.cgi" -Method post -Body @{apiVersion = "1.27"; method = "getNetworkInfo"}

    $Parsed = [ordered]@{}
    ForEach ($line in $result.split("`n")) {
        $Parsed.Add($line.split("=")[0].replace("Network.",''),$line.split("=")[1])
    }

    [pscustomobject]@{
        DHCP =             $Parsed.BootProto                               -eq 'dhcp'
        IPAddress =        $Parsed.'eth0.IPAddress'
        SubnetMask =       $Parsed.'eth0.SubnetMask'
        Gateway =          $Parsed.'Routing.DefaultRouter'
        DNS =              $Parsed.'Resolver.NameServerList'
        HostName =         $Parsed.HostName
        DNSUpdateEnabled = $Parsed.'DNSUpdate.Enabled'                     -eq 'yes'
        DNSHostName =      $Parsed.'DNSUpdate.DNSName'
        Bonjour =          $Parsed.'Bonjour.Enabled'                       -eq 'yes'
        SSH =              $Parsed.'SSH.Enabled'                           -eq 'yes'
        UPnP =             $Parsed.'UpnP.Enabled'                          -eq 'yes'
        WSDiscovery =      $Parsed.'WebService.DiscoveryMode.Discoverable' -eq 'yes'
    }
}