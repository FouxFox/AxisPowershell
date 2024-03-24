Describe "Remove-AxisParameter" {
    Context "Single group removal" {
        It "Remove a single parameter group successfully" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            $device = "192.168.0.100"
            $group = "Brightness"

            Remove-AxisParameter -Device $device -Group $group

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Device -eq $device -and
                $Path -eq "/axis-cgi/param.cgi?action=remove&group=Brightness"
            }
        }

        It "Throws an error when unable to remove a parameter group" {
            Mock @m Invoke-AxisWebApi { return 'Error' }

            $device = "192.168.0.100"
            $group = "Brightness"

            { Remove-AxisParameter -Device $device -Group $group } | Should -Throw "Unable to remove parameter group(s)"
        }
    }

    Context "Multiple group removal" {
        It "Remove multiple parameter groups successfully" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            $device = "192.168.0.100"
            $group = @( "Brightness", "Contrast" )

            Remove-AxisParameter -Device $device -Group $group

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Device -eq $device -and
                $Path -eq "/axis-cgi/param.cgi?action=remove&group=Brightness,Contrast"
            }
        }

        It "Throws an error when unable to remove parameters group" {
            Mock @m Invoke-AxisWebApi { return 'Error' }

            $device = "192.168.0.100"
            $group = @( "Brightness", "Contrast" )

            { Remove-AxisParameter -Device $device -Group $group } | Should -Throw "Unable to remove parameter group(s)"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }