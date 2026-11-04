Describe "Remove-AxisStreamProfile" {
    BeforeAll {
        Mock @m Invoke-AxisWebApi { return @{ data = @{} } }
    }

    Context "Single profile" {
        It "Calls the remove method with the profile name" {
            Remove-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/streamprofile.cgi" -and
                $Method -eq "Post" -and
                $Body.method -eq "remove" -and
                $Body.params.streamProfileName.Count -eq 1 -and
                $Body.params.streamProfileName[0].name -eq "Profile1"
            }
        }
    }

    Context "Multiple profiles" {
        It "Removes all names in one request" {
            Remove-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1","Profile2"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.params.streamProfileName.Count -eq 2 -and
                $Body.params.streamProfileName[1].name -eq "Profile2"
            }
        }
    }

    Context "Errors" {
        It "Warns when the device returns an error" {
            Mock @m Invoke-AxisWebApi { return @{ error = @{ code = 1000; message = "Profile not found" } } }
            Mock @m Write-Warning {}

            Remove-AxisStreamProfile -Device "192.168.0.100" -Name "Missing"

            Should @m -Invoke "Write-Warning" -Exactly -Times 1 -ParameterFilter { $Message -eq "Profile not found" }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
