Describe "Get-AxisViewStatus" {
    Context "View status retrieval" {
        BeforeAll {
            Mock @m Get-AxisParameter {
                return @{
                    'Image.I0.Name'    = 'View Area 1'
                    'Image.I0.Enabled' = 'yes'
                    'Image.I1.Name'    = 'View Area 2'
                    'Image.I1.Enabled' = 'no'
                    'Image.I2.Name'    = 'Quad View'
                    'Image.I2.Enabled' = 'yes'
                }
            }
        }

        It "Requests the view name and enabled parameters" {
            Get-AxisViewStatus -Device "192.168.0.100"

            Should @m -Invoke "Get-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Group -contains 'Image.*.Name' -and
                $Group -contains 'Image.*.Enabled'
            }
        }

        It "Returns one object per view sorted by Id" {
            $result = Get-AxisViewStatus -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 3
            $result[0].Id      | Should -Be 'I0'
            $result[0].Name    | Should -Be 'View Area 1'
            $result[0].Enabled | Should -Be 'yes'
            $result[1].Id      | Should -Be 'I1'
            $result[1].Enabled | Should -Be 'no'
            $result[2].Name    | Should -Be 'Quad View'
        }

        It "Removes combined and disabled views with -RemoveCombinedViews" {
            $result = Get-AxisViewStatus -Device "192.168.0.100" -RemoveCombinedViews

            ($result | Measure-Object).Count | Should -Be 1
            $result.Id | Should -Be 'I0'
        }

        It "Throws when the parameters cannot be fetched" {
            Mock @m Get-AxisParameter { Throw "Unable to fetch parameter(s)" }

            { Get-AxisViewStatus -Device "192.168.0.100" } | Should -Throw "Unable to fetch parameter(s)"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
