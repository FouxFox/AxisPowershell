Describe "Update-AxisParameter" {
    Context "Single parameter update" {
        It "Updates a single parameter successfully" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            $device = "192.168.0.100"
            $parameter = "Brightness"
            $value = "50"

            Update-AxisParameter -Device $device -Parameter $parameter -Value $value

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                $Device -eq $device -and
                $Path -eq "/axis-cgi/param.cgi?action=update&Brightness=50"
            }
        }

        It "Throws an error when unable to update parameter" {
            Mock @m Invoke-AxisWebApi { return 'Error' }

            $device = "192.168.0.100"
            $parameter = "Brightness"
            $value = "50"

            { Update-AxisParameter -Device $device -Parameter $parameter -Value $value } | Should -Throw "Unable to update parameter(s)"
        }
    }

    Context "Multiple parameters update" {
        It "Updates multiple parameters successfully" {
            Mock @m Invoke-AxisWebApi { return 'OK' }

            $device = "192.168.0.100"
            $parameterSet = @{
                Brightness = "50"
                Contrast = "75"
            }

            Update-AxisParameter -Device $device -ParameterSet $parameterSet

            Should @m -Invoke "Invoke-AxisWebApi" -ParameterFilter {
                # Hashtable key order is not deterministic, so compare the parsed query string
                $Query = [System.Web.HttpUtility]::ParseQueryString($Path.Split('?')[1])
                $Device -eq $device -and
                $Path.StartsWith("/axis-cgi/param.cgi?action=update&") -and
                $Query.Count -eq 3 -and
                $Query['Brightness'] -eq '50' -and
                $Query['Contrast'] -eq '75'
            }
        }

        It "Throws an error when unable to update parameters" {
            Mock @m Invoke-AxisWebApi { return 'Error' }

            $device = "192.168.0.100"
            $parameterSet = @{
                Brightness = "50"
                Contrast = "75"
            }

            { Update-AxisParameter -Device $device -ParameterSet $parameterSet } | Should -Throw "Unable to update parameter(s)"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }