Describe "Set-AxisUserAccount" {
    BeforeAll {
        $Script:Pw = ConvertTo-SecureString -AsPlainText -Force "N3w P@ss"
    }

    Context "Success" {
        It "Calls pwdgrp.cgi update with the encoded password" {
            Mock @m Invoke-AxisWebApi { return "OK" }

            Set-AxisUserAccount -Device "192.168.0.100" -User "admin" -Password $Script:Pw

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/pwdgrp.cgi?action=update&user=admin&pwd=N3w%20P%40ss"
            }
        }
    }

    Context "Errors" {
        It "Throws when the device does not answer OK" {
            Mock @m Invoke-AxisWebApi { return "# Error: Error updating password" }

            { Set-AxisUserAccount -Device "192.168.0.100" -User "admin" -Password $Script:Pw } | Should -Throw "Unable to set password"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
