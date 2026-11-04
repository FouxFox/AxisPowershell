Describe "Remove-AxisPSRecordingParams" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        InModuleScope AxisPowerShell {
            $Script:Config.RecordingParams = @{ Default = "videocodec=h265&fps=15"; M4318 = "videocodec=h264" }
        }
        Mock @m Write-ModuleConfiguration { }
    }

    It "Removes the generalized model and persists the change" {
        Remove-AxisPSRecordingParams -ProdNbr "M4318-PVE"

        InModuleScope AxisPowerShell { $Config.RecordingParams.ContainsKey("M4318") } | Should -BeFalse
        InModuleScope AxisPowerShell { $Config.RecordingParams.ContainsKey("Default") } | Should -BeTrue
        Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
    }

    It "Warns and does not write when the model is unknown" {
        Mock @m Write-Warning { }

        Remove-AxisPSRecordingParams -ProdNbr "Q1234"

        Should @m -Invoke "Write-Warning" -ParameterFilter { $Message -like "*Q1234*" } -Times 1
        Should @m -Invoke "Write-ModuleConfiguration" -Times 0
        InModuleScope AxisPowerShell { $Config.RecordingParams.Count } | Should -Be 2
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
