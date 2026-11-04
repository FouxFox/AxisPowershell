Describe "New-AxisStreamProfile" {
    BeforeAll {
        Mock @m Invoke-AxisWebApi { return @{ data = @{} } }
        Mock @m Get-AxisDeviceInfo { return [pscustomobject]@{ ProdNbr = "P3719-PLE" } }
        Mock @m Get-AxisRecordingSupport { return [pscustomobject]@{ SupportedCodecs = "h264,h265" } }
    }

    Context "Explicit parameters" {
        It "Calls the create method with name, description and parameters" {
            New-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1" -Description "Profile 1" -Parameters "videocodec=h264&resolution=1920x1080"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/streamprofile.cgi" -and
                $Method -eq "Post" -and
                $Body.method -eq "create" -and
                $Body.params.streamProfile[0].name -eq "Profile1" -and
                $Body.params.streamProfile[0].description -eq "Profile 1" -and
                $Body.params.streamProfile[0].parameters -eq "videocodec=h264&resolution=1920x1080"
            }
        }

        It "Refuses an unsupported codec without calling the device" {
            { New-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1" -Parameters "videocodec=av1&fps=30" } | Should -Throw "Codec not supported*"

            Should @m -Not -Invoke "Invoke-AxisWebApi"
        }
    }

    Context "Parameters from configuration" {
        It "Uses the model-specific recording parameters when present" {
            InModuleScope AxisPowerShell {
                $Script:Config.RecordingParams = @{
                    Default = "videocodec=h264&fps=15"
                    P3719 = "videocodec=h265&fps=30"
                }
            }

            New-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.params.streamProfile[0].parameters -eq "videocodec=h265&fps=30" -and
                $Body.params.streamProfile[0].description -eq ""
            }
        }

        It "Falls back to the default recording parameters" {
            InModuleScope AxisPowerShell {
                $Script:Config.RecordingParams = @{
                    Default = "videocodec=h264&fps=15"
                }
            }

            New-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Body.params.streamProfile[0].parameters -eq "videocodec=h264&fps=15"
            }
        }
    }

    Context "Errors" {
        It "Warns when the device returns an error" {
            Mock @m Invoke-AxisWebApi { return @{ error = @{ code = 1000; message = "Profile already exists" } } }
            Mock @m Write-Warning {}

            New-AxisStreamProfile -Device "192.168.0.100" -Name "Profile1" -Parameters "videocodec=h264"

            Should @m -Invoke "Write-Warning" -Exactly -Times 1 -ParameterFilter { $Message -eq "Profile already exists" }
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
