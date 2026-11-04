Describe "Get-AxisACAP" {
    Context "ACAP list retrieval" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [xml]@"
<?xml version="1.0" encoding="UTF-8"?>
<reply result="ok">
  <application Name="objectanalytics" ApplicationID="412806" NiceName="AXIS Object Analytics" Vendor="Axis Communications" Version="1.20.36" Status="Stopped" License="None" ConfigurationPage="local/objectanalytics/index.html" VendorHomePage="http://www.axis.com" LicenseName="available" />
  <application Name="vmd" ApplicationID="143440" NiceName="AXIS Video Motion Detection" Vendor="Axis Communications" Version="4.5.13" Status="Running" License="None" ConfigurationPage="local/vmd/config.html" VendorHomePage="http://www.axis.com" LicenseName="available" />
</reply>
"@
            }
        }

        It "Calls applications/list.cgi" {
            Get-AxisACAP -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and $Path -eq "/axis-cgi/applications/list.cgi"
            }
        }

        It "Returns the installed applications" {
            $result = Get-AxisACAP -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 2
            $result[0].Name     | Should -Be 'objectanalytics'
            $result[0].NiceName | Should -Be 'AXIS Object Analytics'
            $result[0].Version  | Should -Be '1.20.36'
            $result[1].Name     | Should -Be 'vmd'
            $result[1].Status   | Should -Be 'Running'
        }

        It "Throws when the device reports an error" {
            Mock @m Invoke-AxisWebApi { return [xml]'<reply result="error"><error code="10" description="Internal error"/></reply>' }

            { Get-AxisACAP -Device "192.168.0.100" } | Should -Throw "Unable to retrieve ACAP information"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
