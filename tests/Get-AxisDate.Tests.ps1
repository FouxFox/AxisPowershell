Describe "Get-AxisDate" {
    Context "Modern firmware (time.cgi)" {
        BeforeAll {
            Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ Version = '11.7.61' } }
            Mock @m Get-CurrentTime { return [datetime]::Parse('2024-08-27T19:30:00Z').ToUniversalTime() }
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    apiVersion = '1.0'
                    data = [pscustomobject]@{
                        dateTime      = '2024-08-27T19:29:56Z'
                        localTime     = '2024-08-27T14:29:56'
                        timeZone      = 'America/Chicago'
                        posixTimeZone = 'CST6CDT,M3.2.0,M11.1.0'
                        dstEnabled    = $true
                    }
                }
            }
        }

        It "Calls time.cgi with getDateTimeInfo" {
            Get-AxisDate -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/time.cgi" -and
                $Body.method -eq 'getDateTimeInfo'
            }
        }

        It "Returns the time information and the offset from the current time" {
            $result = Get-AxisDate -Device "192.168.0.100"

            $result.Device            | Should -Be '192.168.0.100'
            $result.UTCTime           | Should -Be '2024-08-27T19:29:56Z'
            $result.TimeZone          | Should -Be 'America/Chicago'
            $result.PosixTimeZone     | Should -Be 'CST6CDT,M3.2.0,M11.1.0'
            $result.DST               | Should -BeTrue
            $result.OffsetFromCurrent | Should -Be -4
        }

        It "Returns only the offset with -Quiet" {
            Get-AxisDate -Device "192.168.0.100" -Quiet | Should -Be -4
        }
    }

    Context "Legacy firmware (date.cgi)" {
        BeforeAll {
            Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ Version = '9.10.1' } }
            Mock @m Write-Warning {}
            Mock @m Invoke-AxisWebApi { return 'Aug 27, 2024 14:29:56' }
            Mock @m Get-AxisParameter {
                return @{
                    'Time.POSIXTimeZone' = 'CST6CDT,M3.2.0,M11.1.0'
                    'Time.DST.Enabled'   = 'yes'
                }
            }
        }

        It "Calls date.cgi on the requested device" {
            Get-AxisDate -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/admin/date.cgi?action=get"
            }
            Should @m -Invoke "Get-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and $Group -eq 'Time'
            }
        }

        It "Does not calculate an offset and warns" {
            $result = Get-AxisDate -Device "192.168.0.100"

            $result.OffsetFromCurrent | Should -Be 'N/A'
            $result.LocalTime         | Should -BeOfType [datetime]
            $result.PosixTimeZone     | Should -Be 'CST6CDT,M3.2.0,M11.1.0'
            Should @m -Invoke "Write-Warning"
        }

        It "Skips the firmware lookup with -LegacyMethod" {
            Get-AxisDate -Device "192.168.0.100" -LegacyMethod

            Should @m -Not -Invoke "Get-AxisDeviceInfo"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
