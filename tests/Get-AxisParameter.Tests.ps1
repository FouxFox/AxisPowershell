Describe "Get-AxisParameter" {
    Context "Single group parameter retrieval" {
        It "Retrieves a single group parameter successfully" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            $device = "192.168.0.100"
            $group = "System"

            Get-AxisParameter -Device $device -Group $group

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Device -eq $device -and
                $Path -eq "/axis-cgi/param.cgi?action=list&group=System"
            }
        }

        It "Throws an error when unable to fetch parameter" {
            Mock @m Invoke-AxisWebApi { return 'Error' }

            $device = "192.168.0.100"
            $group = "System"

            { Get-AxisParameter -Device $device -Group $group } | Should -Throw "Unable to fetch parameter(s)"
        }
    }

    Context "Multiple group parameters retrieval" {
        It "Retrieves multiple group parameters successfully" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            $device = "192.168.0.100"
            $group = @("System", "Image")

            Get-AxisParameter -Device $device -Group $group

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Device -eq $device -and
                $Path -eq "/axis-cgi/param.cgi?action=list&group=System,Image"
            }
        }

        It "Throws an error when unable to fetch parameters" {
            Mock @m Invoke-AxisWebApi { return 'Error' }

            $device = "192.168.0.100"
            $group = @("System", "Image")

            { Get-AxisParameter -Device $device -Group $group } | Should -Throw "Unable to fetch parameter(s)"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }