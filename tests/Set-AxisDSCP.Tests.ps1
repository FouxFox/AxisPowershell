Describe "Set-AxisDSCP" {
    BeforeAll {
        Mock @m Set-AxisParameter {}
    }

    Context "All classes" {
        It "Uses the default of 26 for all five QoS classes" {
            Set-AxisDSCP -Device "192.168.0.100"

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $ParameterSet.Count -eq 5 -and
                $ParameterSet["Network.QoS.Class1.DSCP"] -eq 26 -and
                $ParameterSet["Network.QoS.Class5.DSCP"] -eq 26
            }
        }

        It "Applies -Value to all five QoS classes" {
            Set-AxisDSCP -Device "192.168.0.100" -Value 46

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $ParameterSet["Network.QoS.Class1.DSCP"] -eq 46 -and
                $ParameterSet["Network.QoS.Class2.DSCP"] -eq 46 -and
                $ParameterSet["Network.QoS.Class3.DSCP"] -eq 46 -and
                $ParameterSet["Network.QoS.Class4.DSCP"] -eq 46 -and
                $ParameterSet["Network.QoS.Class5.DSCP"] -eq 46
            }
        }
    }

    Context "Specific classes" {
        It "Maps each switch to its QoS class and defaults the rest to 26" {
            Set-AxisDSCP -Device "192.168.0.100" -VideoValue 34 -AudioValue 36

            Should @m -Invoke "Set-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $ParameterSet["Network.QoS.Class1.DSCP"] -eq 34 -and
                $ParameterSet["Network.QoS.Class2.DSCP"] -eq 36 -and
                $ParameterSet["Network.QoS.Class3.DSCP"] -eq 26 -and
                $ParameterSet["Network.QoS.Class4.DSCP"] -eq 26 -and
                $ParameterSet["Network.QoS.Class5.DSCP"] -eq 26
            }
        }
    }

    Context "Errors" {
        It "Wraps a parameter failure in a DSCP error" {
            Mock @m Set-AxisParameter { Throw "Unable to update parameter(s)" }

            { Set-AxisDSCP -Device "192.168.0.100" -Value 46 } | Should -Throw "Unable to apply DSCP values"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
