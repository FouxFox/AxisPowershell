Describe "Remove-AxisRecordingProfile" {
    Context "Success" {
        It "Calls removeconfiguration.cgi with the profile id" {
            Mock @m Invoke-AxisWebApi { return @{ root = @{ remove = @{ result = "OK" } } } }

            Remove-AxisRecordingProfile -Device "192.168.0.100" -ProfileId 10

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/record/continuous/removeconfiguration.cgi?profile=10"
            }
        }

        It "Returns nothing" {
            Mock @m Invoke-AxisWebApi { return @{ root = @{ remove = @{ result = "OK" } } } }

            Remove-AxisRecordingProfile -Device "192.168.0.100" -ProfileId 10 | Should -BeNullOrEmpty
        }
    }

    Context "Errors" {
        It "Throws with the device error message" {
            Mock @m Invoke-AxisWebApi { return @{ root = @{ remove = @{ result = "ERROR"; errormsg = "Profile does not exist" } } } }

            { Remove-AxisRecordingProfile -Device "192.168.0.100" -ProfileId 99 } | Should -Throw "Could not remove profile: Profile does not exist"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
