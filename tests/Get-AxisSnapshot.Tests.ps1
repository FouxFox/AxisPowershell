Describe "Get-AxisSnapshot" {
    Context "Snapshot requests" {
        BeforeAll {
            Mock @m Get-AxisDeviceInfo {
                return [pscustomobject]@{
                    ProdShortName  = 'AXIS P3719-PLE'
                    SerialNumber   = 'ACCC8E000001'
                    NumberofLenses = '3'
                }
            }
            # The content is not a real JPEG; image decoding is expected to fail after the download.
            # These tests only verify the device requests, which happen before the image is processed.
            Mock @m Invoke-AxisWebApi { return [pscustomobject]@{ Content = [byte[]](1,2,3,4) } }

            function Invoke-Snapshot {
                Param([hashtable]$Arguments)
                Try {
                    Get-AxisSnapshot @Arguments -ErrorAction Stop
                } Catch {
                    # Image decoding of the fake content fails; ignore
                }
            }
        }

        It "Requests a JPEG for the first requested lens as a web request" {
            Invoke-Snapshot @{ Device = "192.168.0.100"; Lens = @('1','2'); Path = 'TestDrive:' }

            Should @m -Invoke "Get-AxisDeviceInfo" -Exactly -Times 1 -ParameterFilter { $Device -eq "192.168.0.100" }
            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/jpg/image.cgi?camera=1" -and
                $WebRequest -eq $true
            }
        }

        It "Uses the number of lenses from the device information by default" {
            Mock @m Invoke-AxisWebApi { Throw "stop after first request" }

            Invoke-Snapshot @{ Device = "192.168.0.100"; Path = 'TestDrive:' }

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Path -eq "/axis-cgi/jpg/image.cgi?camera=1"
            }
        }

        It "Throws when the device information cannot be retrieved" {
            Mock @m Get-AxisDeviceInfo { Throw "Unable to fetch parameter(s)" }

            { Get-AxisSnapshot -Device "192.168.0.100" -Path 'TestDrive:' } | Should -Throw "Unable to fetch parameter(s)"
            Should @m -Not -Invoke "Invoke-AxisWebApi"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
