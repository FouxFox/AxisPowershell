Describe "AxisPowerShell.Public.Disable-AxisUnusedViews" {      
    Context "When command is called for a device with unused views" {
        BeforeEach { Disable-AxisUnusedViews -Device $TestDevice_IP }
        BeforeAll {
            #Required Mock Functions
            Mock -ModuleName AxisPowerShell Get-AxisDeviceInfo { return @{ProdNbr='P3719-PLE'} }
            Mock -ModuleName AxisPowerShell Invoke-AxisWebApi { return 'Ok!' }
        }

        #Tests
        It 'Gets the Production Number' {
            $cmd = 'Get-AxisDeviceInfo'
            $Filter = {
                $Device -eq $TestDevice_IP
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It 'Invokes the Axis Web API' {
            $cmd = 'Invoke-AxisWebApi'
            $Filter = {
                $Device -eq $TestDevice_IP -and
                $Path -eq "/axis-cgi/param.cgi?action=update&group=Image.I4.Enabled=no"
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }
    }
        
    Context "When command is called for a device without unused views" {
        BeforeEach { Disable-AxisUnusedViews -Device $TestDevice_IP }
        BeforeAll {
            #Mock Functions
            Mock -ModuleName AxisPowerShell Get-AxisDeviceInfo { return @{ProdNbr='Axis1234'} }
            Mock -ModuleName AxisPowerShell Invoke-AxisWebApi { return 'Ok!' }
        }

        #Tests
        It 'Gets the Production Number' {
            $cmd = 'Get-AxisDeviceInfo'
            $Filter = {
                $Device -eq $TestDevice_IP
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It 'Does not invoke the Axis Web API' {
            $cmd = 'Invoke-AxisWebApi'
            Should @m -Not -Invoke $cmd
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }