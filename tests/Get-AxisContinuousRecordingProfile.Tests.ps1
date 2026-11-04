Describe "Get-AxisContinuousRecordingProfile" {
    Context "Continuous recording profile retrieval" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [xml]@"
<?xml version="1.0" encoding="UTF-8"?>
<root xmlns="http://www.axis.com/vapix/http_cgi/record/continuous/listconfiguration1">
  <continuousrecordingconfigurations>
    <continuousrecordingconfiguration profile="22" diskid="SD_DISK" options="videocodec=h265&amp;fps=30&amp;compression=30" />
    <continuousrecordingconfiguration profile="23" diskid="SD_DISK2" options="videocodec=h265&amp;camera=2&amp;fps=30" />
  </continuousrecordingconfigurations>
</root>
"@
            }
        }

        It "Calls listconfiguration.cgi" {
            Get-AxisContinuousRecordingProfile -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/record/continuous/listconfiguration.cgi"
            }
        }

        It "Expands the stream options and defaults camera to 1" {
            $result = Get-AxisContinuousRecordingProfile -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 2
            $result[0].id         | Should -Be '22'
            $result[0].Disk       | Should -Be 'SD_DISK'
            $result[0].videocodec | Should -Be 'h265'
            $result[0].camera     | Should -Be 1
            $result[1].id         | Should -Be '23'
            $result[1].Disk       | Should -Be 'SD_DISK2'
            $result[1].camera     | Should -Be '2'
        }

        It "Returns nothing when no profiles are configured" {
            Mock @m Invoke-AxisWebApi {
                return [xml]'<root><continuousrecordingconfigurations></continuousrecordingconfigurations></root>'
            }

            Get-AxisContinuousRecordingProfile -Device "192.168.0.100" | Should -BeNullOrEmpty
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
