Describe "Add-AxisUserAccount" {
    BeforeAll {
        $Script:Pw = ConvertTo-SecureString -AsPlainText -Force "P@ss w0rd&1"
        $Script:Cred = New-Object System.Management.Automation.PSCredential ("newuser", $Script:Pw)
    }

    Context "Normal user" {
        It "Calls pwdgrp.cgi with the encoded password and default privileges" {
            Mock @m Invoke-AxisWebApi { return "Created account newuser." }

            Add-AxisUserAccount -Device "192.168.0.100" -Credential $Script:Cred -Comment "Temp account"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/pwdgrp.cgi?action=add&user=newuser&pwd=P%40ss%20w0rd%261&grp=users&sgrp=admin:operator:viewer:ptz&comment=Temp%20account" -and
                -not $NoAuth
            }
        }

        It "Uses the given privilege group" {
            Mock @m Invoke-AxisWebApi { return "Created account newuser." }

            Add-AxisUserAccount -Device "192.168.0.100" -Credential $Script:Cred -PrivGroup "operator" -Comment "Temp"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter { $Path.Contains("&sgrp=operator&") }
        }

        It "Throws when the device reports an error" {
            Mock @m Invoke-AxisWebApi { return "# Error: Error adding user" }

            { Add-AxisUserAccount -Device "192.168.0.100" -Credential $Script:Cred -Comment "Temp" } | Should -Throw "Unable to add user"
        }
    }

    Context "Root user" {
        It "Forces the user name root, the root group and skips authentication" {
            Mock @m Invoke-AxisWebApi { return "Created account root." }

            Add-AxisUserAccount -Device "192.168.0.100" -Credential $Script:Cred -AsRoot -NoAuth

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Path.StartsWith("/axis-cgi/pwdgrp.cgi?action=add&user=root&pwd=P%40ss%20w0rd%261&grp=root&sgrp=admin:operator:viewer:ptz") -and
                $NoAuth -eq $true
            }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
