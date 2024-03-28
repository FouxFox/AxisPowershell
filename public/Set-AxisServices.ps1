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
        [Switch]$O3C=$false
    )

    $ParamSet = @{
        "Network.Bonjour.Enabled" = 'no'
        "Network.SSH.Enabled" = 'no'
        "Network.UPnP.Enabled" = 'no'
        "WebService.DiscoveryMode.Discoverable" = 'no'
        "RemoteService.Enabled" = 'no'
    }

    if($Bonjour) {
        $ParamSet["Network.Bonjour.Enabled"] = 'yes'
    }
    if($SSH) {
        $ParamSet["Network.SSH.Enabled"] = 'yes'
    }
    if($UPnP) {
        $ParamSet["Network.UPnP.Enabled"] = 'yes'
    }
    if($WSDiscovery) {
        $ParamSet["WebService.DiscoveryMode.Discoverable"] = 'yes'
    }
    if($O3C) {
        $ParamSet["RemoteService.Enabled"] = 'oneclick'
    }

    Try {
        Update-AxisParameter -Device $Device -ParameterSet $ParamSet
    }
    Catch {
        Throw "Unable to apply Security Settings"
    }
}