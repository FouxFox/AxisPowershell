Describe "Get-AxisRecordingSupport" {
    Context "Recording support retrieval" {
        BeforeAll {
            Mock @m Get-AxisParameter {
                return @{
                    'Properties.LocalStorage.AutoRepair'                       = 'yes'
                    'Properties.LocalStorage.ContinuousRecording'              = 'yes'
                    'Properties.LocalStorage.DiskEncryption'                   = 'yes'
                    'Properties.LocalStorage.DiskHealth'                       = 'yes'
                    'Properties.LocalStorage.ExportRecording'                  = 'yes'
                    'Properties.LocalStorage.FailOverRecording'                = 'no'
                    'Properties.LocalStorage.LocalStorage'                     = 'yes'
                    'Properties.LocalStorage.RequiredFileSystem'               = 'yes'
                    'Properties.LocalStorage.SDCard'                           = 'yes'
                    'Properties.LocalStorage.StorageLimit'                     = 'yes'
                    'Properties.LocalStorage.NbrOfContinuousRecordingProfiles' = '1'
                    'ImageSource.NbrOfSources'                                 = '2'
                    'Properties.Image.Format'                                  = 'jpeg,mjpeg,h264,h265'
                }
            }
        }

        It "Requests the LocalStorage, ImageSource and Image.Format groups" {
            Get-AxisRecordingSupport -Device "192.168.0.100"

            Should @m -Invoke "Get-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Group -contains 'Properties.LocalStorage' -and
                $Group -contains 'ImageSource.NbrOfSources' -and
                $Group -contains 'Properties.Image.Format'
            }
        }

        It "Returns the support flags as booleans" {
            $result = Get-AxisRecordingSupport -Device "192.168.0.100"

            $result.ContinuousRecording              | Should -BeTrue
            $result.FailOverRecording                | Should -BeFalse
            $result.SDCard                           | Should -BeTrue
            $result.NbrOfContinuousRecordingProfiles | Should -Be '1'
            $result.NumberofLenses                   | Should -Be '2'
            $result.SupportedCodecs                  | Should -Be 'jpeg,mjpeg,h264,h265'
        }

        It "Throws when the parameters cannot be fetched" {
            Mock @m Get-AxisParameter { Throw "Unable to fetch parameter(s)" }

            { Get-AxisRecordingSupport -Device "192.168.0.100" } | Should -Throw "Unable to fetch parameter(s)"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
