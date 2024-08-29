
<#
.SYNOPSIS
Retrieves network information for an Axis device.

.DESCRIPTION
The Get-AxisNetworkInfo function retrieves network information for an Axis device, such as IP address, subnet mask, gateway, DNS settings, hostname, and various network service statuses.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.EXAMPLE
Get-AxisNetworkInfo -Device "192.168.1.100"

DHCP             : True
IPAddress        : 192.168.1.100
SubnetMask       : 255.255.255.0
Gateway          : 192.168.1.1
DNS              : 8.8.8.8,8.8.4.4
HostName         : axis-b8a44f4bfed4
Name             : Hallway-Camera
DNSUpdateEnabled : True
DNSHostName      : axis-b8a44f4bfed4.example.com
Bonjour          : False
SSH              : False
UPnP             : False
WSDiscovery      : False

#>
function Get-AxisNetworkInfo {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Device
    )

    #Standard Post method did not work even on current cameras. This was somehow better
    $Groups = @(
        'Network'
        'WebService.DiscoveryMode.Discoverable'
        'RemoteService.Enabled'
    )
    $result = Get-AxisParameter -Device $Device -Group $Groups

    [pscustomobject]@{
        DHCP =             $result.'Network.BootProto'                     -eq 'dhcp'
        IPAddress =        $result.'Network.eth0.IPAddress'
        SubnetMask =       $result.'Network.eth0.SubnetMask'
        Gateway =          $result.'Network.Routing.DefaultRouter'
        DNS =              $result.'Network.Resolver.NameServerList'
        HostName =         $result.'Network.HostName'
        Name =             $result.'Network.UPnP.FriendlyName'
        DNSUpdateEnabled = $result.'Network.DNSUpdate.Enabled'             -eq 'yes'
        DNSHostName =      $result.'Network.DNSUpdate.DNSName'
        Bonjour =          $result.'Network.Bonjour.Enabled'               -eq 'yes'
        SSH =              $result.'Network.SSH.Enabled'                   -eq 'yes'
        UPnP =             $result.'Network.UpnP.Enabled'                  -eq 'yes'
        WSDiscovery =      $result.'WebService.DiscoveryMode.Discoverable' -eq 'yes'
        O3C =              $result.'RemoteService.Enabled'                 -eq 'oneclick'
    }
}
