Describe "Set-AxisNTPClient" {
    BeforeAll {
        Mock @m Invoke-AxisWebApi { return @{ data = @{} } }
        Mock @m Get-AxisNTPClient { return [pscustomobject]@{ Enabled = $true } }
    }

    Context "DHCP" {
        It "Enables the client with serversSource DHCP and fallback servers" {
            Set-AxisNTPClient -Device "192.168.0.100" -DHCP -FallbackServers "ntp1.example.com,ntp2.example.com"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/ntp.cgi" -and
                $Method -eq "Post" -and
                $Body.method -eq "setNTPClientConfiguration" -and
                $Body.params.enabled -eq $true -and
                $Body.params.serversSource -eq "DHCP" -and
                $Body.params.staticServers.Count -eq 2 -and
                $Body.params.staticServers[1] -eq "ntp2.example.com"
            }
        }

        It "Returns the new configuration" {
            $Result = Set-AxisNTPClient -Device "192.168.0.100" -DHCP

            Should @m -Invoke "Get-AxisNTPClient" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" }
            $Result.Enabled | Should -BeTrue
        }
    }

    Context "Static" {
        It "Sends the static servers and NTS key exchange servers as booleans/arrays" {
            Set-AxisNTPClient -Device "192.168.0.100" -Servers "ntp1.example.com" -NTSecurity -KEServers "nts1.example.com"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.params.serversSource -eq "Static" -and
                $Body.params.staticServers[0] -eq "ntp1.example.com" -and
                $Body.params.NTSEnabled -is [bool] -and
                $Body.params.NTSEnabled -eq $true -and
                $Body.params.staticNTSKEServers[0] -eq "nts1.example.com"
            }
        }
    }

    Context "Disabled" {
        It "Sends enabled=false and no server source" {
            Set-AxisNTPClient -Device "192.168.0.100" -Disable

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.params.enabled -eq $false -and
                -not $Body.params.ContainsKey("serversSource")
            }
        }

        It "Warns and does not read back the config when the device returns an error" {
            Mock @m Invoke-AxisWebApi { return @{ error = @{ code = 2000; message = "Invalid request" } } }
            Mock @m Write-Warning {}

            Set-AxisNTPClient -Device "192.168.0.100" -Disable

            Should @m -Invoke "Write-Warning" -Exactly -Times 1 -ParameterFilter { $Message -eq "Invalid request" }
            Should @m -Not -Invoke "Get-AxisNTPClient"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
