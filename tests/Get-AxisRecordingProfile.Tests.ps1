Describe "Get-AxisRecordingProfile" {
    Context "Multi-lens device" {
        BeforeAll {
            Mock @m Get-AxisViewStatus {
                return @(
                    [pscustomobject]@{ Id = 'I0'; Name = 'View Area 1'; Enabled = 'yes' }
                    [pscustomobject]@{ Id = 'I1'; Name = 'View Area 2'; Enabled = 'yes' }
                    [pscustomobject]@{ Id = 'I2'; Name = 'View Area 3'; Enabled = 'yes' }
                    [pscustomobject]@{ Id = 'I3'; Name = 'View Area 4'; Enabled = 'yes' }
                )
            }
            Mock @m Get-AxisContinuousRecordingProfile {
                return @(
                    [pscustomobject]@{ id = '22'; Disk = 'SD_DISK';  camera = 1 }
                    [pscustomobject]@{ id = '23'; Disk = 'SD_DISK';  camera = '2' }
                )
            }
            Mock @m Get-AxisAction {
                return @(
                    [pscustomobject]@{
                        ID = '5'; Name = 'Record Lens 3'; Enabled = $true
                        TemplateToken = 'com.axis.action.unlimited.recording.storage'
                        StreamOptions = 'videocodec=h265&camera=3&fps=30'
                        StorageLocation = 'SD_DISK2'; PrimaryAction = '1'
                    }
                    [pscustomobject]@{
                        ID = '6'; Name = 'Record Lens 2 (duplicate)'; Enabled = $true
                        TemplateToken = 'com.axis.action.unlimited.recording.storage'
                        StreamOptions = 'videocodec=h265&camera=2&fps=30'
                        StorageLocation = 'SD_DISK'; PrimaryAction = '2'
                    }
                    [pscustomobject]@{
                        ID = '7'; Name = 'Send e-mail'; Enabled = $true
                        TemplateToken = 'com.axis.action.fixed.notification.smtp'
                        StreamOptions = $null; StorageLocation = $null; PrimaryAction = '3'
                    }
                )
            }
        }

        It "Counts the lenses without combined views" {
            Get-AxisRecordingProfile -Device "192.168.0.100"

            Should @m -Invoke "Get-AxisViewStatus" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and $RemoveCombinedViews -eq $true
            }
            Should @m -Invoke "Get-AxisContinuousRecordingProfile" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Get-AxisAction" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" }
        }

        It "Returns one row per lens with the correct status" {
            $result = Get-AxisRecordingProfile -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 4

            $result[0].Lens   | Should -Be 1
            $result[0].Status | Should -Be 'OK'
            $result[0].Type   | Should -Be 'Continuous'
            $result[0].Id     | Should -Be '22'
            $result[0].Disk   | Should -Be 'SD_DISK'

            # Lens 2 has both a continuous profile and an action rule
            $result[1].Status | Should -Be 'Error'

            # Lens 3 only has an action rule
            $result[2].Status | Should -Be 'Warning'
            $result[2].Type   | Should -Be 'Action'
            $result[2].Id     | Should -Be '5'
            $result[2].Disk   | Should -Be 'SD_DISK2'

            # Lens 4 has nothing
            $result[3].Status | Should -Be 'Warning'
            $result[3].Error  | Should -Be 'No Profile Exists'
        }
    }

    Context "Single-lens device" {
        It "Assigns action rules without a camera option to lens 1" {
            Mock @m Get-AxisViewStatus { return [pscustomobject]@{ Id = 'I0'; Name = 'View Area 1'; Enabled = 'yes' } }
            Mock @m Get-AxisContinuousRecordingProfile { return @() }
            Mock @m Get-AxisAction {
                return [pscustomobject]@{
                    ID = '1'; Name = 'Record'; Enabled = $true
                    TemplateToken = 'com.axis.action.unlimited.recording.storage'
                    StreamOptions = 'videocodec=h264&fps=15'
                    StorageLocation = 'SD_DISK'; PrimaryAction = '1'
                }
            }

            $result = Get-AxisRecordingProfile -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 1
            $result.Lens | Should -Be 1
            $result.Type | Should -Be 'Action'
            $result.Id   | Should -Be '1'
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
