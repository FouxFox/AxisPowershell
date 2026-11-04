Describe "Get-AxisDSCP" {
    Context "DSCP retrieval" {
        BeforeAll {
            Mock @m Get-AxisParameter {
                return @{
                    'Network.QoS.Class1.Desc' = 'Axis Live Video'
                    'Network.QoS.Class1.DSCP' = '0'
                    'Network.QoS.Class2.Desc' = 'Axis Live Audio'
                    'Network.QoS.Class2.DSCP' = '10'
                    'Network.QoS.Class3.Desc' = 'Axis Management'
                    'Network.QoS.Class3.DSCP' = '20'
                    'Network.QoS.Class4.Desc' = 'Axis MetaData'
                    'Network.QoS.Class4.DSCP' = '30'
                    'Network.QoS.Class5.Desc' = 'Axis Remote Service'
                    'Network.QoS.Class5.DSCP' = '40'
                }
            }
        }

        It "Requests the Network.QoS.* group" {
            Get-AxisDSCP -Device "192.168.0.100"

            Should @m -Invoke "Get-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and $Group -eq 'Network.QoS.*'
            }
        }

        It "Returns one object per class with a cleaned-up class name" {
            $result = Get-AxisDSCP -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 5
            ($result | Where-Object { $_.Class -eq 'Video' }).DSCP      | Should -Be '0'
            ($result | Where-Object { $_.Class -eq 'Audio' }).DSCP      | Should -Be '10'
            ($result | Where-Object { $_.Class -eq 'Management' }).DSCP | Should -Be '20'
            ($result | Where-Object { $_.Class -eq 'Metadata' }).DSCP   | Should -Be '30'
            ($result | Where-Object { $_.Class -eq 'Remote' }).DSCP     | Should -Be '40'
        }

        It "Throws when the parameters cannot be fetched" {
            Mock @m Get-AxisParameter { Throw "Unable to fetch parameter(s)" }

            { Get-AxisDSCP -Device "192.168.0.100" } | Should -Throw "Unable to fetch parameter(s)"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
