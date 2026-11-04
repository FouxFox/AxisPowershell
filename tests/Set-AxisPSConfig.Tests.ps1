Describe "Set-AxisPSConfig" {
    BeforeAll {
        InModuleScope AxisPowerShell $Test_BeforeAll
    }

    BeforeEach {
        InModuleScope AxisPowerShell {
            $Script:Config.Certificate = @{ DefaultAuthority = $false }
            $Script:Config.ProvisionCertificate = $false
            $Script:Config.LogEnabled = $false
            $Script:Config.DNSSuffix = "example.com"
        }
        Mock @m Write-ModuleConfiguration { }
    }

    Context "Paths and suffix" {
        It "Sets every path value and writes the configuration once" {
            Set-AxisPSConfig -FirmwareFolder "C:\Firmware" -LogPath "C:\Logs" -ProvisioningSnapshotPath "C:\Snapshots" -DNSSuffix "lab.example.com"

            InModuleScope AxisPowerShell { $Config.FirmwareFolder } | Should -Be "C:\Firmware"
            InModuleScope AxisPowerShell { $Config.LogPath } | Should -Be "C:\Logs"
            InModuleScope AxisPowerShell { $Config.ProvisioningSnapshotPath } | Should -Be "C:\Snapshots"
            InModuleScope AxisPowerShell { $Config.DNSSuffix } | Should -Be "lab.example.com"
            Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
        }

        It "Leaves values alone when they are not supplied" {
            Set-AxisPSConfig -FirmwareFolder "D:\Firmware"

            InModuleScope AxisPowerShell { $Config.DNSSuffix } | Should -Be "example.com"
            InModuleScope AxisPowerShell { $Config.FirmwareFolder } | Should -Be "D:\Firmware"
        }
    }

    Context "Logging" {
        It "Enables and disables logging" {
            Set-AxisPSConfig -EnableLogging
            InModuleScope AxisPowerShell { $Config.LogEnabled } | Should -BeTrue

            Set-AxisPSConfig -DisableLogging
            InModuleScope AxisPowerShell { $Config.LogEnabled } | Should -BeFalse
        }

        It "Rejects -EnableLogging together with -DisableLogging" {
            { Set-AxisPSConfig -EnableLogging -DisableLogging } | Should -Throw
        }
    }

    Context "Certificate provisioning" {
        It "Refuses to enable certificate provisioning without a default authority" {
            { Set-AxisPSConfig -EnableCertificateProvisioning } | Should -Throw "*No default certificate authority*"

            InModuleScope AxisPowerShell { $Config.ProvisionCertificate } | Should -BeFalse
            Should @m -Invoke "Write-ModuleConfiguration" -Times 0
        }

        It "Enables certificate provisioning when a default authority exists" {
            InModuleScope AxisPowerShell { $Script:Config.Certificate.DefaultAuthority = "CorpCA" }

            Set-AxisPSConfig -EnableCertificateProvisioning

            InModuleScope AxisPowerShell { $Config.ProvisionCertificate } | Should -BeTrue
            Should @m -Invoke "Write-ModuleConfiguration" -Times 1 -Exactly
        }

        It "Disables certificate provisioning" {
            InModuleScope AxisPowerShell { $Script:Config.ProvisionCertificate = $true }

            Set-AxisPSConfig -DisableCertificateProvisioning

            InModuleScope AxisPowerShell { $Config.ProvisionCertificate } | Should -BeFalse
        }
    }
}

# Pull in Test Environment
BeforeAll { . "$PSScriptRoot\TestEnvironment.ps1" }
AfterAll { TerminateTestEnvironment }
