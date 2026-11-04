Describe "Get-AxisPSRecordingParams" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            $Script:Config.RecordingParams = @{
                Default = "videocodec=h265&fps=15"
                P3719 = "videocodec=h264&fps=30"
            }
        }
    }

    It "Returns one object per model" {
        $Result = @(Get-AxisPSRecordingParams)

        $Result.Count | Should -Be 2
        ($Result | Where-Object { $_.Model -eq "Default" }).Parameters | Should -Be "videocodec=h265&fps=15"
        ($Result | Where-Object { $_.Model -eq "P3719" }).Parameters | Should -Be "videocodec=h264&fps=30"
    }

    It "Returns nothing when no parameters are stored" {
        InModuleScope AxisPowerShell { $Script:Config.RecordingParams = @{} }

        @(Get-AxisPSRecordingParams).Count | Should -Be 0
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
