Describe "Set-AxisDNSResolver" {
    BeforeAll {
        Mock @m Invoke-AxisWebApi { return @{ data = @{} } }
        Mock @m Set-AxisParameter {}
    }

    Context "DHCP" {
        It "Calls setResolverConfiguration with useDhcpResolverInfo" {
            Set-AxisDNSResolver -Device "192.168.0.100" -UseDHCP

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/network_settings.cgi" -and
                $Body.method -eq "setResolverConfiguration" -and
                $Body.params.useDhcpResolverInfo -eq $true
            }
            Should @m -Not -Invoke "Set-AxisParameter"
        }

        It "Uses the Network.Resolver.ObtainFromDHCP parameter with -LegacyMethod" {
            Set-AxisDNSResolver -Device "192.168.0.100" -UseDHCP -LegacyMethod

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Parameter -eq "Network.Resolver.ObtainFromDHCP" -and $Value -eq "yes"
            }
            Should @m -Not -Invoke "Invoke-AxisWebApi"
        }
    }

    Context "Static" {
        It "Sends the name servers and search domains" {
            Set-AxisDNSResolver -Device "192.168.0.100" -DNSServers "192.168.0.2","192.168.0.3" -SearchDomains "example.com"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.method -eq "setResolverConfiguration" -and
                $Body.params.useDhcpResolverInfo -eq $false -and
                $Body.params.staticNameServers.Count -eq 2 -and
                $Body.params.staticNameServers[1] -eq "192.168.0.3" -and
                $Body.params.staticSearchDomains[0] -eq "example.com"
            }
        }

        It "Omits staticSearchDomains when none are given" {
            Set-AxisDNSResolver -Device "192.168.0.100" -DNSServers "192.168.0.2"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                -not $Body.params.ContainsKey("staticSearchDomains")
            }
        }

        It "Writes DNSServer1/2 and DomainName with -LegacyMethod" {
            Set-AxisDNSResolver -Device "192.168.0.100" -DNSServers "192.168.0.2","192.168.0.3" -SearchDomains "example.com","test.example.com" -LegacyMethod

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $ParameterSet["Network.Resolver.ObtainFromDHCP"] -eq "no" -and
                $ParameterSet["Network.DNSServer1"] -eq "192.168.0.2" -and
                $ParameterSet["Network.DNSServer2"] -eq "192.168.0.3" -and
                $ParameterSet["Network.DomainName"] -eq "example.com test.example.com"
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
