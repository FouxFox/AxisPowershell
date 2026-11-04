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

        It "Parses the root.-prefixed key/value lines into a hashtable" {
            Mock @m Invoke-AxisWebApi { return "root.System.SerialNumber=ACCC8E000001`nroot.System.Language=English`n" }

            $result = Get-AxisParameter -Device "192.168.0.100" -Group "System"

            $result | Should -BeOfType [Hashtable]
            $result['System.SerialNumber'] | Should -Be 'ACCC8E000001'
            $result['System.Language'] | Should -Be 'English'
            $result.Count | Should -Be 2
        }

        It "Throws an error when the web request fails" {
            Mock @m Invoke-AxisWebApi { Throw "connection refused" }

            $device = "192.168.0.100"
            $group = "System"

            { Get-AxisParameter -Device $device -Group $group } | Should -Throw "Unable to fetch parameter(s)*"
        }

        It "Throws an error when the device answers with a param.cgi error line" {
            Mock @m Invoke-AxisWebApi { return "# Error: Error -1 getting param in group 'System'" }

            { Get-AxisParameter -Device "192.168.0.100" -Group "System" } | Should -Throw "Unable to fetch parameter(s)*"
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
            Mock @m Invoke-AxisWebApi { Throw "connection refused" }

            $device = "192.168.0.100"
            $group = @("System", "Image")

            { Get-AxisParameter -Device $device -Group $group } | Should -Throw "Unable to fetch parameter(s)*"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }