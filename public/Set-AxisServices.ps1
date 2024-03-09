<#
.SYNOPSIS
Sets the services configuration for an Axis device.

.DESCRIPTION
The Set-AxisServices function is used to configure the services of an Axis device. It allows enabling or disabling various services such as Bonjour, SSH, UPnP, and WS-Discovery.
Running the command with no options will set the best practices.

.PARAMETER Device
Specifies the IP address or hostname of the Axis device.

.PARAMETER Bonjour
Specifies whether to enable Bonjour service on the Axis device. 
If not specified, Bonjour will be turned off.

.PARAMETER SSH
Specifies whether to enable SSH service on the Axis device.
If not specified, SSH will be turned off.

.PARAMETER UPnP
Specifies whether to enable UPnP service on the Axis device.
If not specified, UPnP will be turned off.

.PARAMETER WSDiscovery
Specifies whether to enable WS-Discovery service on the Axis device.
If not specified, WS-Discovery will be turned off.

.EXAMPLE
Set-AxisServices -Device "192.168.1.100" -Bonjour -SSH -UPnP -WSDiscovery
Enables Bonjour, SSH, UPnP, and WS-Discovery services on the Axis device with the IP address "192.168.1.100".

.EXAMPLE
Set-AxisServices -Device "axis-camera.local"
Sets the best practices for the services configuration on the Axis device with the hostname "axis-camera.local".

#>
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
        [Switch]$WSDiscovery=$false,

        [Parameter(Mandatory=$false)]
        [Switch]$HttpsBasic=$true
    )

    $URIString = ''
    $URIString += "&Network.Bonjour.Enabled=$(if($Bonjour) {'yes'} else {'no'})"
    $URIString += "&Network.SSH.Enabled=$(if($SSH) {'yes'} else {'no'})"
    $URIString += "&Network.UPnP.Enabled=$(if($UPnP) {'yes'} else {'no'})"
    $URIString += "&WebService.DiscoveryMode.Discoverable=$(if($WSDiscovery) {'yes'} else {'no'})"
    #Network.HTTP.AuthenticationPolicy=digest
    #


    $Param = @{
            Device = $Device
            Path = "/axis-cgi/param.cgi?action=update$($URIString)"
        }
    $result = Invoke-AxisWebApi @Param

    if($result -ne 'OK') {
        Throw "Unable to apply Security Settings"
    }
}