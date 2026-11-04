Describe "Reset-AxisDevice" {
    BeforeAll {
        Mock @m Write-Host {}
    }

    Context "Soft reset" {
        It "Calls factoryDefault with factoryDefaultMode soft" {
            Mock @m Invoke-AxisWebApi { return @{ data = @{} } }

            Reset-AxisDevice -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/firmwaremanagement.cgi" -and
                $Body.method -eq "factoryDefault" -and
                $Body.params.factoryDefaultMode -eq "soft"
            }
        }
    }

    Context "Hard reset" {
        It "Calls factoryDefault with factoryDefaultMode hard" {
            Mock @m Invoke-AxisWebApi { return @{ data = @{} } }

            Reset-AxisDevice -Device "192.168.0.100" -Hard

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.params.factoryDefaultMode -eq "hard"
            }
        }
    }

    Context "Errors" {
        It "Throws with the device error code and message" {
            Mock @m Invoke-AxisWebApi { return @{ error = @{ code = 2003; message = "Method not supported" } } }

            { Reset-AxisDevice -Device "192.168.0.100" } | Should -Throw "Failed: (2003) Method not supported"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
