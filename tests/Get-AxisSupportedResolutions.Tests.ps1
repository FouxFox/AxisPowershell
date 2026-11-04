Describe "Get-AxisSupportedResolutions" {
    Context "Resolution retrieval" {
        BeforeAll {
            Mock @m Invoke-AxisWebApi {
                return [xml]@"
<?xml version="1.0" encoding="UTF-8"?>
<parameterDefinitions xmlns="http://www.axis.com/ParameterDefinitionsSchema" version="1.0" model="P3719-PLE" firmwareVersion="11.7.61">
  <group name="root">
    <group name="Image">
      <group name="I0">
        <group name="Appearance">
          <parameter name="Resolution" value="1920x1080">
            <type>
              <enum>
                <entry value="1920x1080" niceValue="1920x1080 (1080p)"/>
                <entry value="320x240" niceValue="320x240 (QVGA)"/>
                <entry value="1280x720" niceValue="1280x720 (720p)"/>
                <entry value="640x480" niceValue="640x480 (VGA)"/>
              </enum>
            </type>
          </parameter>
        </group>
      </group>
      <group name="I1">
        <group name="Appearance">
          <parameter name="Resolution" value="640x480">
            <type>
              <enum>
                <entry value="640x480" niceValue="640x480 (VGA)"/>
              </enum>
            </type>
          </parameter>
        </group>
      </group>
    </group>
  </group>
</parameterDefinitions>
"@
            }
        }

        It "Requests the resolution parameter definitions as an XML schema" {
            Get-AxisSupportedResolutions -Device "192.168.0.100"

            Should @m -Invoke "Invoke-AxisWebApi" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Path -eq "/axis-cgi/param.cgi?action=listdefinitions&listformat=xmlschema&group=root.Image.*.Appearance.Resolution"
            }
        }

        It "Returns the resolutions of the first lens sorted by width" {
            $result = Get-AxisSupportedResolutions -Device "192.168.0.100"

            ($result | Measure-Object).Count | Should -Be 4
            $result[0] | Should -Be '320x240'
            $result[1] | Should -Be '640x480'
            $result[2] | Should -Be '1280x720'
            $result[3] | Should -Be '1920x1080'
        }

        It "Throws when the request fails" {
            Mock @m Invoke-AxisWebApi { Throw "Connection refused" }

            { Get-AxisSupportedResolutions -Device "192.168.0.100" } | Should -Throw "Connection refused"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
