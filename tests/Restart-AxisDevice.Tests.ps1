Describe "Restart-AxisDevice" {
    Context "Restart" {
        It "Calls restart.cgi on the device" {
            Mock @m Invoke-AxisWebApi { return "OK" }

            Restart-AxisDevice -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/restart.cgi"
            }
        }

        It "Returns nothing" {
            Mock @m Invoke-AxisWebApi { return "<html>restarting</html>" }

            Restart-AxisDevice -Device "192.168.0.100" | Should -BeNullOrEmpty
        }

        It "Propagates a connection error" {
            Mock @m Invoke-AxisWebApi { Throw "Unable to connect" }

            { Restart-AxisDevice -Device "192.168.0.100" } | Should -Throw "Unable to connect"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
