Describe "Get-AxisDeviceStatus" {
    Context "Device ready" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    apiVersion = '1.0'
                    data = [pscustomobject]@{
                        systemready = 'yes'
                        needsetup   = 'no'
                        uptime      = '12345'
                        bootid      = '7'
                    }
                }
            }
        }

        It "Calls systemready.cgi without authentication and with the timeout" {
            Get-AxisDeviceStatus -Device "192.168.0.100" -TimeoutSec 5

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/systemready.cgi" -and
                $NoAuth -eq $true -and
                $TimeoutSec -eq 5 -and
                $Body.method -eq 'systemready' -and
                $Body.params.timeout -eq 5
            }
        }

        It "Returns a Ready status object with the uptime" {
            $result = Get-AxisDeviceStatus -Device "192.168.0.100"

            $result.Status        | Should -Be 'Ready'
            $result.UptimeSeconds | Should -Be '12345'
        }

        It "Returns true with -Quiet" {
            Get-AxisDeviceStatus -Device "192.168.0.100" -Quiet | Should -BeTrue
        }
    }

    Context "Device needs setup" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    apiVersion = '1.0'
                    data = [pscustomobject]@{
                        systemready = 'yes'
                        needsetup   = 'yes'
                        uptime      = '30'
                    }
                }
            }
        }

        It "Reports Needs Setup" {
            (Get-AxisDeviceStatus -Device "192.168.0.100").Status | Should -Be 'Needs Setup'
        }

        It "Returns false with -Quiet" {
            Get-AxisDeviceStatus -Device "192.168.0.100" -Quiet | Should -BeFalse
        }
    }

    Context "Device not ready" {
        It "Reports Not Ready" {
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    data = [pscustomobject]@{ systemready = 'no'; needsetup = 'no'; uptime = '2' }
                }
            }

            (Get-AxisDeviceStatus -Device "192.168.0.100").Status | Should -Be 'Not Ready'
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
