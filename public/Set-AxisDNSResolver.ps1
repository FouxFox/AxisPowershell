<#
.SYNOPSIS
Sets the DNS resolver configuration for an Axis device.

.DESCRIPTION
The Set-AxisDNSResolver function allows you to configure the DNS resolver settings for an Axis device. 
It supports both DHCP and static IP configurations.

.PARAMETER Device
Specifies the Hostname or IP address of the Axis device.

.PARAMETER LegacyMethod
Indicates whether to use the legacy method (Axis parameters) for setting the DNS resolver configuration.
The legacy method supports at most two DNS servers.

.PARAMETER UseDHCP
Specifies whether to use DHCP for obtaining the DNS resolver information. 
This parameter is only applicable when using DHCP.

.PARAMETER DNSServers
Specifies the list of DNS servers to be used for static IP configuration.

.PARAMETER SearchDomains
Specifies the list of search domains to be used for static IP configuration.

.EXAMPLE
Set-AxisDNSResolver -Device 192.168.1.100 -UseDHCP
Configures the Axis device with DHCP for obtaining the DNS resolver information.

.EXAMPLE
Set-AxisDNSResolver -Device 192.168.1.100 -DNSServers "8.8.8.8", "8.8.4.4" -SearchDomains "example.com", "test.com"
Configures the Axis device with static IP configuration, specifying the DNS servers and search domains.
#>

function Set-AxisDNSResolver {
    [cmdletbinding(DefaultParameterSetName='DHCP')]
    Param(
        [Parameter(ParameterSetName='DHCP', Mandatory)]
        [Parameter(ParameterSetName='Static', Mandatory)]
        [String]$Device,

        [Parameter(ParameterSetName='DHCP')]
        [Parameter(ParameterSetName='Static')]
        [Switch]$LegacyMethod,

        [Parameter(ParameterSetName='DHCP', Mandatory)]
        [Switch]$UseDHCP,

        [Parameter(ParameterSetName='Static', Mandatory)]
        [String[]]$DNSServers,

        [Parameter(ParameterSetName='Static')]
        [String[]]$SearchDomains
    )

    if($PSCmdlet.ParameterSetName -eq 'DHCP') {
        if(!$LegacyMethod) {
            $Param = @{
                Device = $Device
                Path = "/axis-cgi/network_settings.cgi"
                Body = @{
                    apiVersion = "1.0"
                    method = "setResolverConfiguration"
                    params = @{
                        useDhcpResolverInfo = $true
                    }
                }
            }
            Invoke-AxisWebApi @Param
        }
        else {
            Update-AxisParameter -Device $Device -Parameter "Network.Resolver.ObtainFromDHCP" -Value "yes"
        }
    }
    else {
        if(!$LegacyMethod) {
            $Param = @{
                Device = $Device
                Path = "/axis-cgi/network_settings.cgi"
                Body = @{
                    apiVersion = "1.0"
                    method = "setResolverConfiguration"
                    params = @{
                        useDhcpResolverInfo = $false
                        staticNameServers = @($DNSServers)
                    }
                }
            }

            if($SearchDomains) {
                $Param.Body.params.Add("staticSearchDomains",@($SearchDomains))
            }

            Invoke-AxisWebApi @Param
        }
        else {
            #Legacy parameters only support two name servers
            $ParamSet = @{
                "Network.Resolver.ObtainFromDHCP" = "no"
                "Network.DNSServer1" = $DNSServers[0]
            }
            if($DNSServers.Count -gt 1) {
                $ParamSet["Network.DNSServer2"] = $DNSServers[1]
            }
            if($SearchDomains) {
                $ParamSet["Network.DomainName"] = $SearchDomains -join ' '
            }
            Update-AxisParameter -Device $Device -ParameterSet $ParamSet
        }
    }
}
