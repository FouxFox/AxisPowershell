Describe "Get-AxisNTPClient" {
    Context "Static NTP servers" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    apiVersion = '1.0'
                    data = [pscustomobject]@{
                        client = [pscustomobject]@{
                            enabled            = $true
                            NTSEnabled         = $false
                            serversSource      = 'static'
                            staticServers      = @('192.168.0.10','192.168.0.11')
                            staticNTSKEServers = @()
                            advertisedServers  = @()
                            synced             = $true
                            timeToNextSync     = 512
                            timeOffset         = 0.004567
                        }
                    }
                }
            }
        }

        It "Posts getNTPInfo to ntp.cgi" {
            Get-AxisNTPClient -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/ntp.cgi" -and
                $Method -eq 'Post' -and
                $Body.method -eq 'getNTPInfo'
            }
        }

        It "Returns the static servers and a rounded time offset" {
            $result = Get-AxisNTPClient -Device "192.168.0.100"

            $result.Enabled             | Should -BeTrue
            $result.NTSecurity          | Should -BeFalse
            $result.ConfigurationSource | Should -Be 'static'
            $result.Servers             | Should -Be '192.168.0.10, 192.168.0.11'
            $result.KEServers           | Should -Be 'N/A'
            $result.FallbackServers     | Should -Be 'N/A'
            $result.Synced              | Should -BeTrue
            $result.TimeOffset          | Should -Be 0
        }
    }

    Context "DHCP NTP servers" {
        It "Uses advertised servers and lists static servers as fallback" {
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    data = [pscustomobject]@{
                        client = [pscustomobject]@{
                            enabled           = $true
                            NTSEnabled        = $false
                            serversSource     = 'DHCP'
                            staticServers     = @('192.168.0.10')
                            advertisedServers = @('192.168.0.1')
                            synced            = $false
                            timeToNextSync    = 0
                            timeOffset        = 0
                        }
                    }
                }
            }

            $result = Get-AxisNTPClient -Device "192.168.0.100"

            $result.Servers         | Should -Be '192.168.0.1'
            $result.FallbackServers | Should -Be '192.168.0.10'
            $result.TimeOffset      | Should -Be 'N/A'
        }
    }

    Context "Error response" {
        It "Writes a warning with the device error message" {
            Mock @m Write-Warning {}
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    error = [pscustomobject]@{ code = 2001; message = 'Access forbidden' }
                }
            }

            Get-AxisNTPClient -Device "192.168.0.100" | Out-Null

            Should @m -Invoke "Write-Warning" -Exactly -Times 1 -ParameterFilter { $Message -eq 'Access forbidden' }
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
