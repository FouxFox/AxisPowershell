Describe "Optimize-AxisRecordingProfiles" {
    BeforeAll {
        Mock @m Remove-AxisAction {}
        Mock @m New-AxisRecordingProfile {}
        Mock @m Write-Warning {}
    }

    Context "All lenses healthy" {
        It "Makes no changes" {
            Mock @m Get-AxisRecordingProfile { return @(
                [pscustomobject]@{ Lens = 1; Status = "OK"; Type = "Continuous" }
                [pscustomobject]@{ Lens = 2; Status = "OK"; Type = "Continuous" }
            ) }

            Optimize-AxisRecordingProfiles -Device "192.168.0.100"

            Should @m -Not -Invoke "Remove-AxisAction"
            Should @m -Not -Invoke "New-AxisRecordingProfile"
        }
    }

    Context "Lens with an Action profile" {
        It "Removes the action rule and creates a continuous profile" {
            $Rule = [pscustomobject]@{ Lens = 2; Status = "Warning"; Type = "Action"; Id = 5; PrimaryAction = 7 }
            Mock @m Get-AxisRecordingProfile { return @(
                [pscustomobject]@{ Lens = 1; Status = "OK"; Type = "Continuous" }
                $Rule
            ) }

            Optimize-AxisRecordingProfiles -Device "192.168.0.100"

            Should @m -Invoke "Remove-AxisAction" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" -and $ActionRule.Id -eq 5 }
            Should @m -Invoke "New-AxisRecordingProfile" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" -and $Lens -eq 2 -and $StreamProfile -eq "EdgeRecording" }
        }
    }

    Context "Lens without any profile" {
        It "Creates a continuous profile only" {
            Mock @m Get-AxisRecordingProfile { return [pscustomobject]@{ Lens = 3; Status = "Warning"; Type = "N/A" } }

            Optimize-AxisRecordingProfiles -Device "192.168.0.100" -StreamProfile "Custom"

            Should @m -Not -Invoke "Remove-AxisAction"
            Should @m -Invoke "New-AxisRecordingProfile" -Exactly -Times 1 -ParameterFilter { $Lens -eq 3 -and $StreamProfile -eq "Custom" }
        }
    }

    Context "Lens with both profile types" {
        It "Warns and changes nothing" {
            Mock @m Get-AxisRecordingProfile { return [pscustomobject]@{ Lens = 1; Status = "Error"; Type = "N/A" } }

            Optimize-AxisRecordingProfiles -Device "192.168.0.100"

            Should @m -Invoke "Write-Warning" -Exactly -Times 1
            Should @m -Not -Invoke "Remove-AxisAction"
            Should @m -Not -Invoke "New-AxisRecordingProfile"
        }

        It "Accepts the device from the pipeline" {
            Mock @m Get-AxisRecordingProfile { return @() }

            "192.168.0.100" | Optimize-AxisRecordingProfiles

            Should @m -Invoke "Get-AxisRecordingProfile" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
