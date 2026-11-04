Describe "Set-AxisIPv4Address" {
    BeforeAll {
        Mock @m Invoke-AxisWebApi { return @{ data = @{} } }
        Mock @m Set-AxisParameter {}
    }

    Context "DHCP" {
        It "Sends configurationMode dhcp for the default interface" {
            Set-AxisIPv4Address -Device "192.168.0.100" -DHCP

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Path -eq "/axis-cgi/network_settings.cgi" -and
                $Body.method -eq "setIPv4AddressConfiguration" -and
                $Body.params.deviceName -eq "eth0" -and
                $Body.params.configurationMode -eq "dhcp" -and
                $Body.params.useStaticDHCPFallback -eq $false
            }
            Should @m -Not -Invoke "Set-AxisParameter"
        }

        It "Sets Network.BootProto with -LegacyMethod" {
            Set-AxisIPv4Address -Device "192.168.0.100" -DHCP -LegacyMethod

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Parameter -eq "Network.BootProto" -and $Value -eq "dhcp"
            }
            Should @m -Not -Invoke "Invoke-AxisWebApi"
        }
    }

    Context "Static" {
        It "Sends the static address, prefix, broadcast and router" {
            Set-AxisIPv4Address -Device "192.168.0.100" -Interface "eth1" -IPAddress 192.168.10.50 -PrefixLength 24 -DefaultGateway 192.168.10.1

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.params.deviceName -eq "eth1" -and
                $Body.params.configurationMode -eq "static" -and
                "$($Body.params.staticDefaultRouter)" -eq "192.168.10.1" -and
                "$($Body.params.staticAddressConfigurations[0].address)" -eq "192.168.10.50" -and
                $Body.params.staticAddressConfigurations[0].PrefixLength -eq 24 -and
                "$($Body.params.staticAddressConfigurations[0].broadcast)" -eq "192.168.10.255"
            }
        }

        It "Writes the legacy network parameters with -LegacyMethod" {
            Set-AxisIPv4Address -Device "192.168.0.100" -IPAddress 192.168.10.50 -PrefixLength 24 -DefaultGateway 192.168.10.1 -LegacyMethod

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $ParameterSet["Network.BootProto"] -eq "none" -and
                "$($ParameterSet["Network.IPAddress"])" -eq "192.168.10.50" -and
                "$($ParameterSet["Network.SubnetMask"])" -eq "255.255.255.0" -and
                "$($ParameterSet["Network.Broadcast"])" -eq "192.168.10.255" -and
                "$($ParameterSet["Network.DefaultRouter"])" -eq "192.168.10.1"
            }
            Should @m -Not -Invoke "Invoke-AxisWebApi"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
