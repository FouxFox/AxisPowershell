Describe "Set-AxisPSRecordingParams" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        InModuleScope AxisPowerShell {
            $Script:Config.RecordingParams = @{ Default = "videocodec=h265&fps=15" }
        }
        Mock @m Write-ModuleConfiguration { }
    }

    It "Adds a new model, generalized from the full product number" {
        Set-AxisPSRecordingParams -ProdNbr "P3738-PLVE" -Parameters "videocodec=h264&fps=30"

        InModuleScope AxisPowerShell { $Config.RecordingParams.ContainsKey("P3738") } | Should -BeTrue
        InModuleScope AxisPowerShell { $Config.RecordingParams.ContainsKey("P3738-PLVE") } | Should -BeFalse
        InModuleScope AxisPowerShell { $Config.RecordingParams.P3738 } | Should -Be "videocodec=h264&fps=30"
        Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
    }

    It "Replaces the parameters of an existing model" {
        InModuleScope AxisPowerShell { $Script:Config.RecordingParams.Add("M3085","old") }

        Set-AxisPSRecordingParams -ProdNbr "M3085" -Parameters "new"

        InModuleScope AxisPowerShell { $Config.RecordingParams.M3085 } | Should -Be "new"
        InModuleScope AxisPowerShell { $Config.RecordingParams.Count } | Should -Be 2
    }

    It "Sets the default parameters and persists them" {
        Set-AxisPSRecordingParams -Default -Parameters "videocodec=h265&fps=30"

        InModuleScope AxisPowerShell { $Config.RecordingParams.Default } | Should -Be "videocodec=h265&fps=30"
        Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
    }

    It "Rejects -Default together with -ProdNbr" {
        { Set-AxisPSRecordingParams -Default -ProdNbr "M3085" -Parameters "x" } | Should -Throw
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
