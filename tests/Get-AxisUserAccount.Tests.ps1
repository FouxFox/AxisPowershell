Describe "Get-AxisUserAccount" {
    Context "User account retrieval" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return "admin=`"root,admin2`"`r`noperator=`"root,admin2,operator1`"`r`nviewer=`"root,admin2,operator1,viewer1`"`r`nptz=`"root,admin2`"`r`ndigusers=`"root,admin2,operator1,viewer1`"`r`n"
            }
        }

        It "Calls pwdgrp.cgi with action=get" {
            Get-AxisUserAccount -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and $Path -eq "/axis-cgi/pwdgrp.cgi?action=get"
            }
        }

        It "Returns one object per privilege group without quotes" {
            $result = Get-AxisUserAccount -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 5
            $result[0].PrivGroup | Should -Be 'admin'
            $result[0].Users     | Should -Be 'root,admin2'
            $result[2].PrivGroup | Should -Be 'viewer'
            $result[2].Users     | Should -Be 'root,admin2,operator1,viewer1'
            $result[4].PrivGroup | Should -Be 'digusers'
        }

        It "Throws when the request fails" {
            Mock @m Invoke-AxisWebApi { Throw "Connection refused" }

            { Get-AxisUserAccount -Device "192.168.0.100" } | Should -Throw "Connection refused"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
