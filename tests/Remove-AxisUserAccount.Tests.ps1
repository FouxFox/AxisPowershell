Describe "Remove-AxisUserAccount" {
    Context "Success" {
        It "Is exported by the module" {
            Get-Command -Module AxisPowerShell -Name Remove-AxisUserAccount | Should -Not -BeNullOrEmpty
        }

        It "Calls pwdgrp.cgi remove with the user" {
            Mock @m Invoke-AxisWebApi { return "OK" }

            Remove-AxisUserAccount -Device "192.168.0.100" -User "olduser"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/pwdgrp.cgi?action=remove&user=olduser"
            }
        }
    }

    Context "Errors" {
        It "Throws when the device does not answer OK" {
            Mock @m Invoke-AxisWebApi { return "# Error: user does not exist" }

            { Remove-AxisUserAccount -Device "192.168.0.100" -User "olduser" } | Should -Throw "Unable to remove user"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
