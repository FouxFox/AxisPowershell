<#
.SYNOPSIS
Sets the IP address configuration for an Axis device.

.DESCRIPTION
The Set-AxisIPv4Address function is used to configure the IP address settings for an Axis device. It supports both DHCP and static IP address configurations (See Note).

.PARAMETER Device
Specifies the name or IP address of the Axis device.

.PARAMETER Interface
Which interface to modify. On most devices this is eth0. This option is ignored when using the LegacyMethod.

.PARAMETER LegacyMethod
Assigns an IP using Axis Parameters rather than the Network Settings API.

.PARAMETER DHCP
Indicates whether to configure the device to use DHCP for obtaining an IP address.

.PARAMETER IPAddress
The IP address that should be assigned to the device.

.PARAMETER PrefixLength
The subnet size for the network. For example, "24" would indicate a /24 or 255.255.255.0.

.PARAMETER DefaultGateway
The address of the local router on the subnet.

.EXAMPLE
Set-AxisIPv4Address -Device "192.168.0.100" -DHCP
Configures the Axis device with the IP address 192.168.0.100 and enables DHCP for obtaining the IP address.

.NOTES

#>
function Set-AxisIPv4Address {
    [cmdletbinding(DefaultParameterSetName='DHCP')]
    [Alias("Set-AxisIPAddress")]
    Param(
        [Parameter(ParameterSetName='DHCP', Mandatory)]
        [Parameter(ParameterSetName='Static', Mandatory)]
        [String]$Device,

        [Parameter(ParameterSetName='DHCP')]
        [Parameter(ParameterSetName='Static')]
        [String]$Interface="eth0",

        [Parameter(ParameterSetName='DHCP')]
        [Parameter(ParameterSetName='Static')]
        [Switch]$LegacyMethod,

        [Parameter(ParameterSetName='DHCP')]
        [Switch]$DHCP,

        [Parameter(ParameterSetName='Static', Mandatory)]
        [IPAddress]$IPAddress,

        [Parameter(ParameterSetName='Static', Mandatory)]
        [Int]$PrefixLength,

        [Parameter(ParameterSetName='Static', Mandatory)]
        [IPAddress]$DefaultGateway

        
    )

    if($PSCmdlet.ParameterSetName -eq 'DHCP') {
        if(!$LegacyMethod) {
            $Param = @{
                Device = $Device
                Path = "/axis-cgi/network_settings.cgi"
                Body = @{
                    apiVersion = "1.0"
                    method = "setIPv4AddressConfiguration"
                    params = @{
                        deviceName = $Interface
                        configurationMode = "dhcp"
                        useStaticDHCPFallback = $false
                    }
                }
            }
            Invoke-AxisWebApi @Param
        }
        else {
            Update-AxisParameter -Device $Device -Parameter "Network.BootProto" -Value "dhcp"
        }
    }
    else {
        $IPSubnetInfo = Get-SubnetInformation -IPv4Address $IPAddress -Prefix $PrefixLength

        if(!$LegacyMethod) {
            $Param = @{
                Device = $Device
                Path = "/axis-cgi/network_settings.cgi"
                Body = @{
                    apiVersion = "1.0"
                    method = "setIPv4AddressConfiguration"
                    params = @{
                        deviceName = $Interface
                        configurationMode = "static"
                        staticDefaultRouter = $DefaultGateway
                        staticAddressConfigurations = @(@{
                            address = $IPAddress
                            PrefixLength = $PrefixLength
                            broadcast = $IPSubnetInfo.BroadcastAddress
                        })
                    }
                }
            }
            Invoke-AxisWebApi @Param
        }
        else {
            $ParamSet = @{
                "Network.BootProto" = "none"
                "Network.IPAddress" = $IPAddress
                "Network.SubnetMask" = $IPSubnetInfo.SubnetMask
                "Network.Broadcast" = $IPSubnetInfo.BroadcastAddress
                "Network.DefaultRouter" = $DefaultGateway
            }
            Update-AxisParameter -Device $Device -ParameterSet $ParamSet 
        }
    }
}