Describe "Remove-AxisAction" {
    BeforeAll {
        Mock @m Invoke-AxisSoapRequest { return [xml]"<Body/>" }
    }

    Context "Rule with configuration" {
        It "Removes the rule and then its primary action configuration" {
            $Rule = [pscustomobject]@{ Id = 5; PrimaryAction = 7; Name = "Record" }

            Remove-AxisAction -Device "192.168.0.100" -ActionRule $Rule

            Should @m -Invoke "Invoke-AxisSoapRequest" -Exactly -Times 2 -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Invoke-AxisSoapRequest" -Exactly -Times 1 -ParameterFilter {
                $Body -eq "<aa:RemoveActionRule><aa:RuleID>5</aa:RuleID></aa:RemoveActionRule>" -and
                $Namespaces.aa -eq "http://www.axis.com/vapix/ws/action1"
            }
            Should @m -Invoke "Invoke-AxisSoapRequest" -Exactly -Times 1 -ParameterFilter {
                $Body -eq "<aa:RemoveActionConfiguration><aa:ConfigurationID>7</aa:ConfigurationID></aa:RemoveActionConfiguration>"
            }
        }
    }

    Context "Rule without configuration" {
        It "Removes only the rule" {
            $Rule = [pscustomobject]@{ Id = 5; PrimaryAction = $null }

            Remove-AxisAction -Device "192.168.0.100" -ActionRule $Rule

            Should @m -Invoke "Invoke-AxisSoapRequest" -Exactly -Times 1
            Should @m -Not -Invoke "Invoke-AxisSoapRequest" -ParameterFilter { $Body.Contains("RemoveActionConfiguration") }
        }
    }

    Context "Errors" {
        It "Does not remove the configuration when the rule removal faults" {
            Mock @m Invoke-AxisSoapRequest { Throw "SOAP Fault: Rule not found - (Sender)" }
            $Rule = [pscustomobject]@{ Id = 5; PrimaryAction = 7 }

            { Remove-AxisAction -Device "192.168.0.100" -ActionRule $Rule } | Should -Throw "SOAP Fault*"

            Should @m -Invoke "Invoke-AxisSoapRequest" -Exactly -Times 1
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
