Describe "Set-AxisStreamProfile" {
    BeforeAll {
        Mock @m Invoke-AxisWebApi { return @{ data = @{} } }
        Mock @m Get-AxisStreamProfile { return [pscustomobject]@{ name = "Profile1"; description = "Old"; parameters = "videocodec=h264" } }
        Mock @m Remove-AxisStreamProfile {}
        Mock @m New-AxisStreamProfile {}
    }

    Context "Preconditions" {
        It "Throws and makes no call when nothing is to be changed" {
            { Set-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1" } | Should -Throw "At least one of the parameters*"

            Should @m -Not -Invoke "Invoke-AxisWebApi"
            Should @m -Not -Invoke "Remove-AxisStreamProfile"
        }
    }

    Context "Update" {
        It "Calls the update method with only the supplied fields" {
            Set-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1" -Parameters "videocodec=h265&fps=15"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/streamprofile.cgi" -and
                $Body.method -eq "update" -and
                $Body.params.streamProfile[0].name -eq "Profile1" -and
                $Body.params.streamProfile[0].parameters -eq "videocodec=h265&fps=15" -and
                -not $Body.params.streamProfile[0].ContainsKey("description")
            }
            Should @m -Not -Invoke "Remove-AxisStreamProfile"
            Should @m -Not -Invoke "New-AxisStreamProfile"
        }

        It "Warns when the device returns an error" {
            Mock @m Invoke-AxisWebApi { return @{ error = @{ code = 1000; message = "Profile not found" } } }
            Mock @m Write-Warning {}

            Set-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1" -Description "New"

            Should @m -Invoke "Write-Warning" -Exactly -Times 1 -ParameterFilter { $Message -eq "Profile not found" }
        }
    }

    Context "Rename" {
        It "Recreates the profile under the new name with the old settings" {
            Set-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1" -NewName "Profile2"

            Should @m -Not -Invoke "Invoke-AxisWebApi"
            Should @m -Invoke "Remove-AxisStreamProfile" -Exactly -Times 1 -ParameterFilter { $Name -eq "Profile1" }
            Should @m -Invoke "New-AxisStreamProfile" -Exactly -Times 1 -ParameterFilter {
                $Name -eq "Profile2" -and $Description -eq "Old" -and $Parameters -eq "videocodec=h264"
            }
        }

        It "Does not remove anything when the profile does not exist" {
            Mock @m Get-AxisStreamProfile { return $null }

            { Set-AxisStreamProfile -Device "192.168.0.100" -Name "Missing" -NewName "Profile2" } | Should -Throw "*not found*"

            Should @m -Not -Invoke "Remove-AxisStreamProfile"
            Should @m -Not -Invoke "New-AxisStreamProfile"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
