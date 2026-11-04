Describe "Get-AxisNetworkInfo" {
    Context "Network information retrieval" {
        BeforeAll {
            Mock @m Get-AxisParameter {
                return @{
                    'Network.BootProto'                     = 'dhcp'
                    'Network.eth0.IPAddress'                = '192.168.0.100'
                    'Network.eth0.SubnetMask'               = '255.255.255.0'
                    'Network.Routing.DefaultRouter'         = '192.168.0.1'
                    'Network.Resolver.NameServerList'       = '192.168.0.2,192.168.0.3'
                    'Network.HostName'                      = 'axis-accc8e000001'
                    'Network.UPnP.FriendlyName'             = 'Hallway-Camera'
                    'Network.DNSUpdate.Enabled'             = 'yes'
                    'Network.DNSUpdate.DNSName'             = 'axis-accc8e000001.example.com'
                    'Network.Bonjour.Enabled'               = 'no'
                    'Network.SSH.Enabled'                   = 'no'
                    'Network.UpnP.Enabled'                  = 'no'
                    'WebService.DiscoveryMode.Discoverable' = 'no'
                    'RemoteService.Enabled'                 = 'oneclick'
                }
            }
        }

        It "Requests the Network, WS-Discovery and RemoteService groups" {
            Get-AxisNetworkInfo -Device "192.168.0.100"

            Should @m -Invoke "Get-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Group -contains 'Network' -and
                $Group -contains 'WebService.DiscoveryMode.Discoverable' -and
                $Group -contains 'RemoteService.Enabled'
            }
        }

        It "Converts yes/no values to booleans and keeps strings" {
            $result = Get-AxisNetworkInfo -Device "192.168.0.100"

            $result.DHCP             | Should -BeTrue
            $result.IPAddress        | Should -Be '192.168.0.100'
            $result.Gateway          | Should -Be '192.168.0.1'
            $result.DNS              | Should -Be '192.168.0.2,192.168.0.3'
            $result.Name             | Should -Be 'Hallway-Camera'
            $result.DNSUpdateEnabled | Should -BeTrue
            $result.DNSHostName      | Should -Be 'axis-accc8e000001.example.com'
            $result.Bonjour          | Should -BeFalse
            $result.SSH              | Should -BeFalse
            $result.UPnP             | Should -BeFalse
            $result.WSDiscovery      | Should -BeFalse
            $result.O3C              | Should -BeTrue
        }

        It "Throws when the parameters cannot be fetched" {
            Mock @m Get-AxisParameter { Throw "Unable to fetch parameter(s)" }

            { Get-AxisNetworkInfo -Device "192.168.0.100" } | Should -Throw "Unable to fetch parameter(s)"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
