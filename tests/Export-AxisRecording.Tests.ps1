Describe "Export-AxisRecording" {
    BeforeAll {
        $Script:Start = Get-Date "2024-01-01 13:00:00"
        $Script:Stop = Get-Date "2024-01-01 14:30:00"
        $Script:OutFile = Join-Path $TestDrive "recording.mkv"

        Mock @m Invoke-AxisWebApi {}
        Mock @m Get-AxisRecording { return [pscustomobject]@{ recordingid = "20240101_130000_ABCD_B8A44F000000"; diskid = "SD_DISK" } }
    }

    Context "Successful export" {
        It "Looks up the recording and downloads it with 24-hour timestamps" {
            Export-AxisRecording -Device "192.168.0.100" -StartTimeUTC $Script:Start -StopTimeUTC $Script:Stop -FilePath $Script:OutFile

            Should @m -Invoke "Get-AxisRecording" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $StartTimeUTC -eq $Script:Start -and
                $StopTimeUTC -eq $Script:Stop -and
                $MaxResults -eq 1 -and
                $ThrowErrorOnTimeDifference -eq $true
            }
            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $OutFile -eq $Script:OutFile -and
                $Path -eq "/axis-cgi/record/export/exportrecording.cgi?schemaversion=1&recordingid=20240101_130000_ABCD_B8A44F000000&diskid=SD_DISK&exportformat=matroska&starttime=2024-01-01T13:00:00&stoptime=2024-01-01T14:30:00"
            }
        }

        It "Passes a custom format" {
            Export-AxisRecording -Device "192.168.0.100" -StartTimeUTC $Script:Start -StopTimeUTC $Script:Stop -FilePath $Script:OutFile -Format "mp4"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter { $Path.Contains("&exportformat=mp4&") }
        }
    }

    Context "Preconditions" {
        It "Rejects a path without a file extension and does not touch the device" {
            { Export-AxisRecording -Device "192.168.0.100" -StartTimeUTC $Script:Start -StopTimeUTC $Script:Stop -FilePath $TestDrive } | Should -Throw "Invalid Path*"

            Should @m -Not -Invoke "Get-AxisRecording"
            Should @m -Not -Invoke "Invoke-AxisWebApi"
        }

        It "Throws and does not download when no recording exists" {
            Mock @m Get-AxisRecording { return $null }

            { Export-AxisRecording -Device "192.168.0.100" -StartTimeUTC $Script:Start -StopTimeUTC $Script:Stop -FilePath $Script:OutFile } | Should -Throw "No recording found*"

            Should @m -Not -Invoke "Invoke-AxisWebApi"
        }
    }

    Context "Device time difference" {
        It "Retries without the time check when the user confirms" {
            Mock @m Get-AxisRecording { Throw "Time difference" } -ParameterFilter { $ThrowErrorOnTimeDifference -eq $true }

            Export-AxisRecording -Device "192.168.0.100" -StartTimeUTC $Script:Start -StopTimeUTC $Script:Stop -FilePath $Script:OutFile -Confirm:$false

            Should @m -Invoke "Get-AxisRecording" -Exactly -Times 1 -ParameterFilter { $ThrowErrorOnTimeDifference -eq $false }
            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1
        }

        It "Does nothing with -WhatIf when the device time is off" {
            Mock @m Get-AxisRecording { Throw "Time difference" } -ParameterFilter { $ThrowErrorOnTimeDifference -eq $true }

            Export-AxisRecording -Device "192.168.0.100" -StartTimeUTC $Script:Start -StopTimeUTC $Script:Stop -FilePath $Script:OutFile -WhatIf

            Should @m -Not -Invoke "Get-AxisRecording" -ParameterFilter { $ThrowErrorOnTimeDifference -eq $false }
            Should @m -Not -Invoke "Invoke-AxisWebApi"
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
