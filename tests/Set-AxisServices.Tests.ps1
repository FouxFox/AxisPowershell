Describe "Set-AxisServices" {
    BeforeAll {
        Mock @m Set-AxisParameter {}
    }

    Context "Best practices" {
        It "Disables every discovery and remote service by default" {
            Set-AxisServices -Device "192.168.0.100"

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $ParameterSet["Network.Bonjour.Enabled"] -eq "no" -and
                $ParameterSet["Network.SSH.Enabled"] -eq "no" -and
                $ParameterSet["Network.UPnP.Enabled"] -eq "no" -and
                $ParameterSet["WebService.DiscoveryMode.Discoverable"] -eq "no" -and
                $ParameterSet["RemoteService.Enabled"] -eq "no"
            }
        }
    }

    Context "Selective enable" {
        It "Enables only the requested services" {
            Set-AxisServices -Device "192.168.0.100" -SSH -O3C

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $ParameterSet["Network.Bonjour.Enabled"] -eq "no" -and
                $ParameterSet["Network.SSH.Enabled"] -eq "yes" -and
                $ParameterSet["Network.UPnP.Enabled"] -eq "no" -and
                $ParameterSet["WebService.DiscoveryMode.Discoverable"] -eq "no" -and
                $ParameterSet["RemoteService.Enabled"] -eq "oneclick"
            }
        }
    }

    Context "Errors" {
        It "Wraps a parameter failure" {
            Mock @m Set-AxisParameter { Throw "Unable to update parameter(s)" }

            { Set-AxisServices -Device "192.168.0.100" } | Should -Throw "Unable to apply Security Settings"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
