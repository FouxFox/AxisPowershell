Describe "AxisPowerShell.Public.Disable-AxisUnusedViews" {      
    Context "When command is called for a device with unused views" {
        BeforeEach { Disable-AxisUnusedViews -Device $TestDevice_IP }
        BeforeAll {
            #Required Mock Functions
            Mock @m Get-AxisViewStatus { return @(
                [pscustomobject]@{Id="I0";Name="View Area 1";Enabled="yes"}
                [pscustomobject]@{Id="I1";Name="View Area 2";Enabled="no"}
                [pscustomobject]@{Id="I2";Name="Camera 3";Enabled="yes"}
                [pscustomobject]@{Id="I3";Name="Camera 4";Enabled="no"}
                [pscustomobject]@{Id="I4";Name="Quad View";Enabled="yes"}
            )}
            Mock @m Update-AxisParameter {}
        }

        #Tests
        It 'Gets Current View Status' {
            $cmd = 'Get-AxisViewStatus'
            $Filter = {
                $Device -eq $TestDevice_IP
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It 'Disables only views required' {
            $cmd = 'Update-AxisParameter'
            $Filter = {
                $Device -eq $TestDevice_IP -and
                $ParameterSet['Image.I4.Enabled'] -eq "no"
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }
    }
        
    Context "When command is called for a device without unused views" {
        BeforeEach { Disable-AxisUnusedViews -Device $TestDevice_IP }
        BeforeAll {
            #Mock Functions
            Mock @m Get-AxisViewStatus { return @(
                [pscustomobject]@{Id="I0";Name="View Area 1";Enabled="yes"}
                [pscustomobject]@{Id="I1";Name="View Area 2";Enabled="no"}
                [pscustomobject]@{Id="I2";Name="Camera 3";Enabled="yes"}
                [pscustomobject]@{Id="I3";Name="Camera 4";Enabled="no"}
                [pscustomobject]@{Id="I4";Name="Quad View";Enabled="no"}
            )}
            Mock @m Update-AxisParameter { return 'Ok!' }
        }

        #Tests
        It 'Gets Current View Status' {
            $cmd = 'Get-AxisViewStatus'
            $Filter = {
                $Device -eq $TestDevice_IP
            }
            Should @m -Invoke $cmd -Exactly -Times 1 -ParameterFilter $Filter
        }

        It 'Does not update values' {
            $cmd = 'Update-AxisParameter'
            Should @m -Not -Invoke $cmd
        }
    }

    #Set up Config
    BeforeAll { InModuleScope AxisPowerShell $Test_BeforeAll }
}

#Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }