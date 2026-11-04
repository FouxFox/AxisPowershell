Describe "Get-AxisDeviceInfo" {
    Context "Device information retrieval" {
        BeforeAll {
            Mock @m Get-AxisParameter {
                return @{
                    'Properties.System.Architecture' = 'aarch64'
                    'Properties.System.HardwareID'   = '797'
                    'Properties.System.Soc'          = 'Ambarella S5'
                    'Properties.System.SerialNumber' = 'ACCC8E000001'
                    'Properties.Firmware.Version'    = '11.7.61'
                    'Properties.Firmware.BuildDate'  = 'Nov 15 2023 19:02'
                    'Brand.ProdNbr'                  = 'P3719-PLE'
                    'Brand.ProdFullName'             = 'AXIS P3719-PLE Network Camera'
                    'Brand.ProdType'                 = 'Network Camera'
                    'Brand.ProdShortName'            = 'AXIS P3719-PLE'
                    'ImageSource.NbrOfSources'       = '4'
                }
            }
        }

        It "Requests the firmware, system, brand and image source parameter groups" {
            Get-AxisDeviceInfo -Device "192.168.0.100"

            Should @m -Invoke "Get-AxisParameter" -Exactly -Times 1 -ParameterFilter {
                $Device -eq "192.168.0.100" -and
                $Group -contains 'Properties.Firmware' -and
                $Group -contains 'Properties.System' -and
                $Group -contains 'Brand' -and
                $Group -contains 'ImageSource'
            }
        }

        It "Maps the parameters to the output object" {
            $result = Get-AxisDeviceInfo -Device "192.168.0.100"

            $result.ProdNbr        | Should -Be 'P3719-PLE'
            $result.Version        | Should -Be '11.7.61'
            $result.SerialNumber   | Should -Be 'ACCC8E000001'
            $result.ProdShortName  | Should -Be 'AXIS P3719-PLE'
            $result.FWBuildDate    | Should -Be 'Nov 15 2023 19:02'
            $result.NumberofLenses | Should -Be '4'
            $result.Architecture   | Should -Be 'aarch64'
        }

        It "Throws when the parameters cannot be fetched" {
            Mock @m Get-AxisParameter { Throw "Unable to fetch parameter(s)" }

            { Get-AxisDeviceInfo -Device "192.168.0.100" } | Should -Throw "Unable to fetch parameter(s)"
        }
    }

    # Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
