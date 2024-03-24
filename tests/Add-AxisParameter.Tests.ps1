Describe "Add-AxisParameter" {
    Context "Single parameter addition" {
        It "Adds a single parameter successfully" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            $device = "192.168.0.100"
            $template = "Template1"
            $group = "Group1"
            $parameter = "Brightness"
            $value = "50"

            Add-AxisParameter -Device $device -Template $template -Group $group -Parameter $parameter -Value $value

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Device -eq $device -and
                $Path -eq "/axis-cgi/param.cgi?action=add&template=Template1&group=Group1&Brightness=50"
            }
        }

        It "Throws an error when unable to add parameter" {
            Mock @m Invoke-AxisWebApi { return 'Error' }

            $device = "192.168.0.100"
            $template = "Template1"
            $group = "Group1"
            $parameter = "Brightness"
            $value = "50"

            { Add-AxisParameter -Device $device -Template $template -Group $group -Parameter $parameter -Value $value } | Should -Throw "Unable to add parameter(s)"
        }
    }

    Context "Multiple parameters addition" {
        It "Adds multiple parameters successfully" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            $device = "192.168.0.100"
            $template = "Template1"
            $group = "Group1"
            $parameterSet = @{
                Brightness = "50"
                Contrast = "75"
            }

            Add-AxisParameter -Device $device -Template $template -Group $group -ParameterSet $parameterSet

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Device -eq $device -and
                $Path -eq "/axis-cgi/param.cgi?action=add&template=Template1&group=Group1&Brightness=50&Contrast=75"
            }
        }

        It "Throws an error when unable to add parameters" {
            Mock @m Invoke-AxisWebApi { return 'Error' }

            $device = "192.168.0.100"
            $template = "Template1"
            $group = "Group1"
            $parameterSet = @{
                Brightness = "50"
                Contrast = "75"
            }

            { Add-AxisParameter -Device $device -Template $template -Group $group -ParameterSet $parameterSet } | Should -Throw "Unable to add parameter(s)"
        }
    }
    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }