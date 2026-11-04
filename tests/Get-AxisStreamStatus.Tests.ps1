Describe "Get-AxisStreamStatus" {
    Context "Stream status retrieval" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{
                    apiVersion = '1.0'
                    method = 'getAllStreams'
                    data = [pscustomobject]@{
                        streams = @(
                            [pscustomobject]@{
                                destination_address = '192.168.0.5'
                                destination_port    = 15670
                                direction           = 'outgoing'
                                encrypted           = $false
                                id                  = 71
                                media               = 'video'
                                mime                = 'video/x-h265'
                                multicast           = $false
                                options             = [pscustomobject]@{ camera = '1'; fps = '15'; videocodec = 'h265'; resolution = '3840x2160' }
                                path                = '/axis-media/media.amp'
                                source_address      = '192.168.0.100'
                                source_port         = 50000
                                state               = 'playing'
                                stream_protocol     = 'RTP'
                                transport_protocol  = 'UDP'
                                user_agent          = 'ExampleRTSPClient/1.0'
                            }
                        )
                    }
                }
            }
        }

        It "Calls streamstatus.cgi with getAllStreams" {
            Get-AxisStreamStatus -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/streamstatus.cgi" -and
                $Body.apiVersion -eq '1.0' -and
                $Body.method -eq 'getAllStreams'
            }
        }

        It "Returns the stream objects" {
            $result = Get-AxisStreamStatus -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 1
            $result.id                  | Should -Be 71
            $result.state               | Should -Be 'playing'
            $result.options.videocodec  | Should -Be 'h265'
            $result.destination_address | Should -Be '192.168.0.5'
        }

        It "Returns nothing when there are no streams" {
            Mock @m Invoke-AxisWebApi {
                return [pscustomobject]@{ data = [pscustomobject]@{ streams = @() } }
            }

            Get-AxisStreamStatus -Device "192.168.0.100" | Should -BeNullOrEmpty
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
