Describe "Get-AxisZipStreamSupport" {
    # Get-AxisZipStreamSupport is still "in development" and not exported; call it inside the module scope
    Context "Zipstream profile retrieval" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [xml]'<ZipstreamProfiles SchemaVersion="1"><Profile Name="storage" Strength="20"/><Profile Name="live" Strength="10"/></ZipstreamProfiles>'
            }
        }

        It "Calls listprofiles.cgi with schema version 1" {
            InModuleScope AxisPowerShell { Get-AxisZipStreamSupport -Device "192.168.0.100" }

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/zipstream/listprofiles.cgi?schemaversion=1"
            }
        }

        It "Returns the device response unchanged" {
            $result = InModuleScope AxisPowerShell { Get-AxisZipStreamSupport -Device "192.168.0.100" }

            $result.ZipstreamProfiles.Profile.Count | Should -Be 2
            $result.ZipstreamProfiles.Profile[0].Name | Should -Be 'storage'
        }

        It "Throws when the request fails" {
            Mock @m Invoke-AxisWebApi { Throw "Connection refused" }

            { InModuleScope AxisPowerShell { Get-AxisZipStreamSupport -Device "192.168.0.100" } } | Should -Throw "Connection refused"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
