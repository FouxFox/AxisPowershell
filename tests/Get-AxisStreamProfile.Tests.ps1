Describe "Get-AxisStreamProfile" {
    Context "Stream profile retrieval" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    apiVersion = '1.0'
                    method = 'list'
                    data = [pscustomobject]@{
                        streamProfile = @(
                            [pscustomobject]@{
                                name = 'ConfigToolProfile'
                                description = ''
                                parameters = 'videocodec=h265&resolution=1280x720&fps=10&compression=70&videobitratemode=mbr&videomaxbitrate=800'
                            }
                            [pscustomobject]@{
                                name = 'Recording'
                                description = 'Storage'
                                parameters = 'videocodec=h265&videobitratemode=vbr&videozstrength=20&videozgopmode=dynamic&videozprofile=storage'
                            }
                        )
                        maxProfiles = 26
                    }
                }
            }
        }

        It "Posts the list method to streamprofile.cgi with an empty name list" {
            Get-AxisStreamProfile -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/streamprofile.cgi" -and
                $Method -eq 'Post' -and
                $Body.method -eq 'list' -and
                $Body.params.streamProfileName.Count -eq 0
            }
        }

        It "Requests only the named profiles when -Name is used" {
            Get-AxisStreamProfile -Device "192.168.0.100" -Name 'Recording'

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.params.streamProfileName.Count -eq 1 -and
                $Body.params.streamProfileName[0].name -eq 'Recording'
            }
        }

        It "Returns the raw profiles by default" {
            $result = Get-AxisStreamProfile -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 2
            $result[0].name       | Should -Be 'ConfigToolProfile'
            $result[0].parameters | Should -Match '^videocodec=h265'
        }

        It "Expands the parameters with -ExpandParameters" {
            $result = Get-AxisStreamProfile -Device "192.168.0.100" -ExpandParameters

            $result[0].Name           | Should -Be 'ConfigToolProfile'
            $result[0].videocodec     | Should -Be 'h265'
            $result[0].resolution     | Should -Be '1280x720'
            $result[0].videomaxbitrate | Should -Be '800'
            $result[1].Description    | Should -Be 'Storage'
            $result[1].videozprofile  | Should -Be 'storage'
        }

        It "Returns the maximum number of profiles with -MaxProfiles" {
            Get-AxisStreamProfile -Device "192.168.0.100" -MaxProfiles | Should -Be 26
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
