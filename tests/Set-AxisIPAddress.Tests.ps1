Describe "Set-AxisIPAddress" {
    Context "Alias" {
        It "Resolves to Set-AxisIPv4Address" {
            $Alias = Get-Alias -Name Set-AxisIPAddress -ErrorAction Stop
            $Alias.ResolvedCommandName | Should -Be "Set-AxisIPv4Address"
        }

        It "Configures DHCP through the Network Settings API" {
            Mock @m Invoke-AxisWebApi { return @{ data = @{} } }

            Set-AxisIPAddress -Device "192.168.0.100" -DHCP

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/network_settings.cgi" -and
                $Body.method -eq "setIPv4AddressConfiguration" -and
                $Body.params.configurationMode -eq "dhcp"
            }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
