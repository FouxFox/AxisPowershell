<#
.SYNOPSIS
Enable or disable a specific service on an Axis device.

.DESCRIPTION
Set-AxisServices configures a single service state per invocation on an Axis device by
enabling or disabling one of the supported services:
    - Bonjour
    - SSH
    - UPnP
    - WSDiscovery (Web Services Discovery)
    - O3C (Axis One-Click Cloud Connection)

You must specify exactly one service and whether you want to -Enable or -Disable it.

.PARAMETER Device
The hostname or IP address of the Axis device to configure.

.PARAMETER Enable
Specifies the service to enable. Accepts one of: Bonjour, SSH, UPnP, WSDiscovery, O3C.
Mutually exclusive with -Disable.

.PARAMETER Disable
Specifies the service to disable. Accepts one of: Bonjour, SSH, UPnP, WSDiscovery, O3C.
Mutually exclusive with -Enable.

.EXAMPLE
Set-AxisServices -Device 192.168.1.50 -Enable SSH
Enables SSH on the device at 192.168.1.50.

.EXAMPLE
Set-AxisServices -Device cam01.local -Disable UPnP
Disables UPnP on the device cam01.local.

#>
function Set-AxisServices {
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory, Position=0, ParameterSetName='Enable')]
        [Parameter(Mandatory, Position=0, ParameterSetName='Disable')]
        [String]$Device,

        [Parameter(Mandatory, ParameterSetName='Enable')]
        [ValidateSet("Bonjour","SSH","UPnP","WSDiscovery","O3C")]
        [string]$Enable,

        [Parameter(Mandatory, ParameterSetName='Disable')]
        [ValidateSet("Bonjour","SSH","UPnP","WSDiscovery","O3C")]
        [string]$Disable
    )

    $Services = @{
        Bonjour = @{
            ParameterName = "Network.Bonjour.Enabled"
            Enabled = 'yes'
            Disabled = 'no'
        }
        SSH = @{
            ParameterName = "Network.SSH.Enabled"
            Enabled = 'yes'
            Disabled = 'no'
        }
        UPnP = @{
            ParameterName = "Network.UPnP.Enabled"
            Enabled = 'yes'
            Disabled = 'no'
        }
        WSDiscovery = @{
            ParameterName = "WebService.DiscoveryMode.Discoverable"
            Enabled = 'yes'
            Disabled = 'no'
        }
        O3C = @{
            ParameterName = "RemoteService.Enabled"
            Enabled = 'oneclick'
            Disabled = 'no'
        }
    }

    Try {
        if($PSCmdlet.ParameterSetName -eq 'Enable') {
            Update-AxisParameter -Device $Device -Parameter $Services[$Enable].ParameterName -Value $Services[$Enable].Enabled
            return
        }
        Update-AxisParameter -Device $Device -Parameter $Services[$Disable].ParameterName -Value $Services[$Disable].Disabled
    }
    Catch {
        Throw "Unable to apply Security Settings"
    }
}