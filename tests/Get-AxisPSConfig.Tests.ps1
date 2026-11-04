Describe "Get-AxisPSConfig" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
        InModuleScope AxisPowerShell {
            $Script:Config.FirmwareFolder = "C:\Firmware"
            $Script:Config.ProvisioningSnapshotPath = "C:\Snapshots"
            $Script:Config.LogPath = "C:\Logs"
            $Script:Config.LogEnabled = $true
        }
    }

    It "Returns the configured values" {
        $Result = Get-AxisPSConfig

        $Result.FirmwareFolder | Should -Be "C:\Firmware"
        $Result.DNSSuffix | Should -Be "example.com"
        $Result.ProvisioningSnapshotPath | Should -Be "C:\Snapshots"
        $Result.LogPath | Should -Be "C:\Logs"
        $Result.LogEnabled | Should -BeTrue
    }

    It "Returns exactly the five documented properties" {
        $Result = Get-AxisPSConfig

        @($Result.PSObject.Properties).Count | Should -Be 5
        $Result.PSObject.Properties.Name | Should -Contain "LogEnabled"
    }

    It "Does not expose the credential" {
        $Result = Get-AxisPSConfig

        $Result.PSObject.Properties.Name | Should -Not -Contain "Credential"
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
