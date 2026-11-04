Describe "Get-AxisRecording" {
    Context "Recording list retrieval" {
        BeforeAll {
            Mock @m Get-AxisDate { return [pscustomobject]@{ Device = '192.168.0.100'; OffsetFromCurrent = 2 } }
            Mock @m Write-Warning {}
            Mock @m Invoke-AxisWebApi {
                return [xml]@"
<?xml version="1.0" encoding="UTF-8"?>
<root xmlns="http://www.axis.com/vapix/http_cgi/record/list1">
  <recordings totalNumberOfRecordings="2" numberOfRecordings="2">
    <recording diskid="SD_DISK" recordingid="20240829_064435_1A2B_ACCC8E000001" starttime="2024-08-29T06:44:35.123456Z" stoptime="2024-08-29T07:44:35.123456Z" recordingtype="continuous" eventid="continuous" eventtrigger="continuous" recordingstatus="completed" source="1" locked="No">
      <video mimetype="video/x-h265" width="1920" height="1080" framerate="30:1" />
    </recording>
    <recording diskid="SD_DISK" recordingid="20240829_074435_3C4D_ACCC8E000001" starttime="2024-08-29T07:44:35.123456Z" stoptime="" recordingtype="continuous" eventid="continuous" eventtrigger="continuous" recordingstatus="recording" source="1" locked="No">
      <video mimetype="video/x-h265" width="1920" height="1080" framerate="30:1" />
    </recording>
  </recordings>
</root>
"@
            }
        }

        It "Formats the start and stop time with a 24-hour clock" {
            $start = [datetime]'2024-08-29 06:44:35'
            $stop  = [datetime]'2024-08-29 15:44:35'

            Get-AxisRecording -Device "192.168.0.100" -StartTimeUTC $start -StopTimeUTC $stop

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/record/list.cgi?starttime=2024-08-29T06:44:35Z&stoptime=2024-08-29T15:44:35Z"
            }
        }

        It "Adds the source and maximum number of results to the query" {
            $start = [datetime]'2024-08-29 06:44:35'
            $stop  = [datetime]'2024-08-29 15:44:35'

            Get-AxisRecording -Device "192.168.0.100" -StartTimeUTC $start -StopTimeUTC $stop -Lens 2 -MaxResults 10

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Path -eq "/axis-cgi/record/list.cgi?starttime=2024-08-29T06:44:35Z&stoptime=2024-08-29T15:44:35Z&source=2&maxnumberofresults=10"
            }
        }

        It "Returns the recording elements" {
            $start = [datetime]'2024-08-29 06:44:35'
            $stop  = [datetime]'2024-08-29 15:44:35'

            $result = Get-AxisRecording -Device "192.168.0.100" -StartTimeUTC $start -StopTimeUTC $stop

            ($result | Measure-Object).Count | Should -Be 2
            $result[0].recordingid     | Should -Be '20240829_064435_1A2B_ACCC8E000001'
            $result[0].recordingstatus | Should -Be 'completed'
            $result[1].recordingstatus | Should -Be 'recording'
            Should @m -Not -Invoke "Write-Warning"
        }

        It "Warns and returns nothing when there are no recordings" {
            Mock @m Invoke-AxisWebApi {
                return [xml]'<root><recordings totalNumberOfRecordings="0" numberOfRecordings="0"></recordings></root>'
            }
            $start = [datetime]'2024-08-29 06:44:35'
            $stop  = [datetime]'2024-08-29 15:44:35'

            $result = Get-AxisRecording -Device "192.168.0.100" -StartTimeUTC $start -StopTimeUTC $stop

            $result | Should -BeNullOrEmpty
            Should @m -Invoke "Write-Warning" -Exactly -Times 1
        }
    }

    Context "Device time offset" {
        BeforeAll {
            Mock @m Get-AxisDate { return [pscustomobject]@{ Device = '192.168.0.100'; OffsetFromCurrent = -120 } }
            Mock @m Write-Warning {}
            Mock @m Invoke-AxisWebApi {
                return [xml]'<root><recordings totalNumberOfRecordings="0" numberOfRecordings="0"></recordings></root>'
            }
        }

        It "Warns when the device time is off by more than 60 seconds" {
            $start = [datetime]'2024-08-29 06:44:35'
            $stop  = [datetime]'2024-08-29 15:44:35'

            Get-AxisRecording -Device "192.168.0.100" -StartTimeUTC $start -StopTimeUTC $stop

            Should @m -Invoke "Write-Warning" -ParameterFilter { $Message -like "*greater than 60 seconds*" }
        }

        It "Throws with -ThrowErrorOnTimeDifference" {
            $start = [datetime]'2024-08-29 06:44:35'
            $stop  = [datetime]'2024-08-29 15:44:35'

            { Get-AxisRecording -Device "192.168.0.100" -StartTimeUTC $start -StopTimeUTC $stop -ThrowErrorOnTimeDifference } |
                Should -Throw "*greater than 60 seconds*"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
